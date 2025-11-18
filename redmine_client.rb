require 'net/http'
require 'json'
require 'uri'

class RedmineClient
  attr_reader :base_url, :api_key, :username, :password, :http_username, :http_password
  attr_accessor :debug

  # Khởi tạo client với API key hoặc username/password
  # Options:
  #   - api_key: API key từ Redmine (hoặc truyền qua tham số thứ 2)
  #   - username: Username Redmine để đăng nhập
  #   - password: Password Redmine để đăng nhập
  #   - http_username: HTTP Basic Auth username (cho nginx/apache protection)
  #   - http_password: HTTP Basic Auth password (cho nginx/apache protection)
  #   - debug: Bật chế độ debug (mặc định: false)
  #   - verify_ssl: Kiểm tra SSL certificate (mặc định: true)
  def initialize(base_url, api_key = nil, options = {})
    @base_url = base_url.chomp('/')
    @api_key = api_key
    @username = options[:username]
    @password = options[:password]
    @http_username = options[:http_username]
    @http_password = options[:http_password]
    @debug = options[:debug] || false
    @verify_ssl = options.fetch(:verify_ssl, true)

    log_debug "Initializing RedmineClient"
    log_debug "  Base URL: #{@base_url}"
    log_debug "  Redmine Auth: #{auth_method}"
    log_debug "  HTTP Basic Auth: #{http_auth_configured? ? 'Enabled (username: ' + @http_username + ')' : 'Disabled'}"
    log_debug "  API Key present: #{!@api_key.nil? && !@api_key.empty?}"
    log_debug "  Redmine Username: #{@username}" if @username
    log_debug "  SSL verification: #{@verify_ssl}"
  end

  def auth_method
    methods = []
    methods << 'HTTP Basic Auth' if http_auth_configured?

    if @api_key && !@api_key.empty?
      methods << 'Redmine API Key'
    elsif @username && @password
      methods << 'Redmine Username/Password'
    else
      methods << 'None (will fail!)'
    end

    methods.join(' + ')
  end

  def http_auth_configured?
    @http_username && @http_password && !@http_username.empty? && !@http_password.empty?
  end

  # Lấy thông tin chi tiết của một issue
  def get_issue(issue_id, options = {})
    # Merge includes instead of overriding
    default_includes = ['journals', 'attachments', 'relations', 'watchers']

    if options[:include]
      # Combine default includes with custom includes
      custom_includes = options[:include].split(',').map(&:strip)
      all_includes = (default_includes + custom_includes).uniq
      merged_options = options.merge(include: all_includes.join(','))
    else
      merged_options = options.merge(include: default_includes.join(','))
    end

    query_string = URI.encode_www_form(merged_options)
    url = URI("#{@base_url}/issues/#{issue_id}.json?#{query_string}")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      log_debug "Error response body: #{response.body}"
      { 'error' => "Failed to fetch issue: #{response.code} - #{response.message}", 'response_body' => response.body }
    end
  end

  # Lấy danh sách issues với filter
  def get_issues(params = {})
    query_string = URI.encode_www_form(params)
    url = URI("#{@base_url}/issues.json?#{query_string}")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      log_debug "Error response body: #{response.body}"
      { 'error' => "Failed to fetch issues: #{response.code} - #{response.message}", 'response_body' => response.body }
    end
  end

  # Lấy thông tin user
  def get_user(user_id)
    url = URI("#{@base_url}/users/#{user_id}.json")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      log_debug "Error response body: #{response.body}"
      { 'error' => "Failed to fetch user: #{response.code} - #{response.message}", 'response_body' => response.body }
    end
  end

  # Lấy danh sách projects
  def get_projects
    url = URI("#{@base_url}/projects.json")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      log_debug "Error response body: #{response.body}"
      { 'error' => "Failed to fetch projects: #{response.code} - #{response.message}", 'response_body' => response.body }
    end
  end

  private

  def make_request(url)
    log_debug "\nMaking request to: #{url}"

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')

    # Tắt SSL verification nếu cần (cho self-signed certificates)
    if http.use_ssl? && !@verify_ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      log_debug "  SSL verification disabled"
    end

    request = Net::HTTP::Get.new(url.request_uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    # 1. Thêm HTTP Basic Auth (cho nginx/apache protection layer)
    if http_auth_configured?
      request.basic_auth(@http_username, @http_password)
      log_debug "  Using HTTP Basic Auth: #{@http_username}"
    end

    # 2. Thêm Redmine authentication (API key hoặc username/password)
    if @api_key && !@api_key.empty?
      request['X-Redmine-API-Key'] = @api_key
      log_debug "  Using Redmine API Key authentication"
    elsif @username && @password
      # Nếu đã có HTTP basic auth, không thể dùng basic auth cho Redmine
      # Trong trường hợp này, nên dùng API key thay vì username/password
      if http_auth_configured?
        log_debug "  WARNING: Cannot use Redmine username/password with HTTP Basic Auth"
        log_debug "  Please use REDMINE_API_KEY instead"
      else
        request.basic_auth(@username, @password)
        log_debug "  Using Redmine Basic Auth with username: #{@username}"
      end
    else
      log_debug "  WARNING: No Redmine authentication provided!"
    end

    log_debug "  Request headers: #{request.to_hash.inspect}"

    begin
      response = http.request(request)
      log_debug "  Response: #{response.code} #{response.message}"
      log_debug "  Response headers: #{response.to_hash.inspect}"
      response
    rescue StandardError => e
      log_debug "  Request failed with exception: #{e.class} - #{e.message}"
      raise
    end
  end

  def log_debug(message)
    puts "[DEBUG] #{message}" if @debug
  end
end
