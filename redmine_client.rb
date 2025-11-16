require 'net/http'
require 'json'
require 'uri'

class RedmineClient
  attr_reader :base_url, :api_key

  def initialize(base_url, api_key)
    @base_url = base_url.chomp('/')
    @api_key = api_key
  end

  # Lấy thông tin chi tiết của một issue
  def get_issue(issue_id)
    url = URI("#{@base_url}/issues/#{issue_id}.json")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      { 'error' => "Failed to fetch issue: #{response.code} - #{response.message}" }
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
      { 'error' => "Failed to fetch issues: #{response.code} - #{response.message}" }
    end
  end

  # Lấy thông tin user
  def get_user(user_id)
    url = URI("#{@base_url}/users/#{user_id}.json")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      { 'error' => "Failed to fetch user: #{response.code} - #{response.message}" }
    end
  end

  # Lấy danh sách projects
  def get_projects
    url = URI("#{@base_url}/projects.json")
    response = make_request(url)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      { 'error' => "Failed to fetch projects: #{response.code} - #{response.message}" }
    end
  end

  private

  def make_request(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')

    request = Net::HTTP::Get.new(url)
    request['X-Redmine-API-Key'] = @api_key
    request['Content-Type'] = 'application/json'

    http.request(request)
  end
end
