# coding: utf-8

class Mechanize::Page
  def resolve_url url
    url.nil? ? '' : mech.agent.resolve(url, self).to_s
  end

  def_delegator :parser, :extract, :extract
  def_delegator :parser, :extract_all, :extract_all


  #############################################
  # match matches a regex on the body of a Mechanize node, optionally taking a
  # block for work to be done on the result. The block form should be used if
  # you would want to use a cascade form even if match fails.
  # TODO This method does not use the options parameter
  #############################################
  def match(regex, options={}, &block)
    if result = text.match(regex)
      item = result[1]
    end
    filtered = yield(item,result) if block_given?
    filtered || item
  end

  def text
    root.to_s.encode('UTF-8')
  end

end

class Nokogiri::XML::Node
  #############################################
  # Returns data within an element matching selector. If you are looking for a
  # node and not data, use search. Defaults to the text in the matched node,
  # but can grab anything if you define which attribute.
  #
  # Ex:
  #   node.extract("a.class", attr: :href)
  #############################################
  def extract(*selectors, &block)
    options = selectors.last.is_a?(Hash) ? selectors.pop : {}
    if result = search(*selectors).first
      process(result,options,&block)
    end
  end

  #############################################
  # Same as extract, but returns all results in an array
  #############################################
  def extract_all(selector, options={}, &block)
    if results = search(selector)
      results.map do |result|
        process(result, options, &block)
      end
    end
  end

  #############################################
  # Attempts to match by the passed in selector and will return a concatenation
  # of all texty things in all child elements. If an attr is passed, process will
  # return that attribute. If a block is passed, the result will be executed
  # in that context. Don't cascade because process may render nil, opt for the
  # block syntax.
  #############################################
  def process(item, options)
    text = options[:attr] ? item[options[:attr]] : item.text
    if text
      text.strip!
      text.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      text = text.match(options[:regexp]) {|m| text = m[1]} if options[:regexp]
      filtered = yield(text, item) if block_given? and text.present?
      (filtered || text).blank? ? nil : filtered || text
    end
  end
end

module MechanizeAdapter

  ###########################
  # Get a page with mechanize
  ###########################

  def get url, options={}, &block
    @request_meter.mark
    @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @agent.pluggable_parser.default = Mechanize::Page
    GapCrawler.logger.info "GET: #{url}"
    @current_url = url
    if block_given?
      safe_request url, options, &block
    else
      request url, options
    end
  end

  def safe_request url, options, &block
    begin
      try_n_times do
        yield page_preprocess fetcher { agent_get(url, options) }
      end
    rescue => exception
      GapCrawler.logger.warn exception.backtrace[0]
      GapCrawler.logger.warn exception.to_s

      if GapCrawler.job
        send_link_exception_to_management url, exception
      end
    end
  end

  def fetcher &block
    begin
      block.call
    rescue => e
      if crawl_controller.job.use_proxy?
        GapCrawler.logger.info 'Starting work through a proxy...'
        switch_proxy
      end

      raise e
    end
  end

  def agent_get url, options = {}
    @agent.get url, options[:parameters] || [], options[:referer], options[:headers] || {}
  end

  def send_link_exception_to_management url, exception
    exception_msg = {}
    exception_msg[:message] = exception.message
    exception_msg[:error_type] = exception.class.to_s
    exception_msg[:trace] = exception.backtrace.to_json
    exception_msg[:job_id] = crawl_controller.job.job_id
    exception_msg[:job_link_id] = @job_link_id
    exception_msg[:url] = url
    exception_msg[:collector_id] = crawl_controller.job.crawl_id

    management_adapter = ManagementAdapter.new crawl_controller.instance_variable_get :@args
    management_adapter.send_link_exception exception_msg
  end

  def try_get url, times
    page = get url
    if times == 0 || page
      page
    else
      sleep rand 5
      try_get url, times - 1
    end
  end

  def request url, options = {}
    begin
      Timeout::timeout(120){ page_preprocess agent_get(url, options) }
    rescue Mechanize::ResponseCodeError
      return false
    rescue Mechanize::ResponseReadError => e
      return e.force_parse
    rescue Timeout::Error
      GapCrawler.logger.info "Timeout::Error Link: #{url}"
      return false
    end
  end

  def page_preprocess page
    page
  end

  def try_n_times
    tries = 1
    begin
      yield
    # We should consider limiting the errors that this catches
    rescue => e
      tries += 1
      GapCrawler.logger.warn e
      GapCrawler.logger.warn "Trying again!" if tries <= @number_of_tries
      retry if tries <= @number_of_tries
        GapCrawler.logger.error "No more attempt!"
        raise e
    end
  end

  ##########################################################################################
  # Post a form with mechanize, accepts a hash as parameters or a string, headers are a hash
  # Will not attempt to correct base_url
  ##########################################################################################

  def post url, parameters = {}, headers = {}
    @request_meter.mark

    try_n_times do
      @current_url = url
      escaped_url = URI.escape url

      GapCrawler.logger.debug "POST: #{escaped_url}\nParameters: #{parameters}\nCustom Headers: #{headers}"

      fetcher { @agent.post url, parameters, headers }
    end
  end

  def switch_proxy
    @proxies = @proxy.get_proxy_list if @proxies.empty? || @proxy.expired?

    proxy = @proxies.shift

    if proxy
      GapCrawler.logger.info "Trying with: #{proxy[:ip]}:#{proxy[:port]}"

      @agent.keep_alive = false
      @agent.open_timeout = 30
      @agent.read_timeout = 30

      switch_user_agent

      @agent.set_proxy proxy[:ip], proxy[:port]
    else
      remove_proxy
    end
  end

  def switch_proxymesh
    proxy_list = ['us-wa.proxymesh.com', 'fr.proxymesh.com', 'jp.proxymesh.com',
      'au.proxymesh.com', 'de.proxymesh.com', 'open.proxymesh.com']
    proxy = proxy_list.sample
    switch_user_agent
    GapCrawler.logger.info "Trying with: #{proxy}"
    @agent.set_proxy(proxy, 31280, 'gapcrawler', 'gapcrawler')
  end

  def smart_switch_proxy
    [
      -> { switch_proxymesh },
      -> { switch_proxy },
      -> { remove_proxy }
    ].sample.call
  end

  def switch_user_agent
    user_agent_alias = Mechanize::AGENT_ALIASES.keys
    user_agent_alias.delete "Mechanize"
    @agent.user_agent_alias = user_agent_alias.sample
  end

  def remove_proxy
    @agent.set_proxy nil, nil
    GapCrawler.logger.info "Disabled proxy."
  end

  def resume_proxy
    if @current_proxy
      proxy = @current_proxy
      @current_proxy = nil
      GapCrawler.logger.info "Trying with: #{proxy[0]}:#{proxy[1]}"
      @agent.set_proxy *proxy
    else
      switch_proxy
    end
  end

  def pause_proxy
    @current_proxy = [@agent.proxy_addr, @agent.proxy_port].compact.presence
    remove_proxy
  end

  def proxy_enabled?
    @agent.proxy_addr.present?
  end
end
