require 'net/http'
require 'json'
require 'uri'

class GitHubClient
  attr_reader :token

  def initialize(token, options = {})
    @token = token
    @debug = options[:debug] || false
  end

  # Parse GitHub URL to extract owner, repo, and number
  # Supports formats:
  # - https://github.com/owner/repo/issues/123
  # - https://github.com/owner/repo/pull/123
  def parse_github_url(url)
    return nil unless url

    # Match GitHub URL pattern
    pattern = %r{github\.com/([^/]+)/([^/]+)/(issues|pull)/(\d+)}
    match = url.match(pattern)

    if match
      {
        owner: match[1],
        repo: match[2],
        type: match[3], # 'issues' or 'pull'
        number: match[4].to_i
      }
    else
      nil
    end
  end

  # Fetch PR or Issue info from GitHub
  def get_pr_info(url)
    parsed = parse_github_url(url)
    return nil unless parsed

    # GitHub API endpoint
    # Note: Both PRs and Issues can use the /issues endpoint
    # PRs are also issues in GitHub's API
    api_url = "https://api.github.com/repos/#{parsed[:owner]}/#{parsed[:repo]}/issues/#{parsed[:number]}"

    debug_log "Fetching GitHub #{parsed[:type]} info: #{api_url}"

    uri = URI(api_url)
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Authorization'] = "token #{@token}" if @token

    debug_log "  GitHub Token present: #{!@token.nil? && !@token.empty?}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    debug_log "  Response: #{response.code} #{response.message}"

    if response.code == '200'
      data = JSON.parse(response.body)
      {
        number: data['number'],
        title: data['title'],
        state: data['state'],
        comments: data['comments'],
        created_at: data['created_at'],
        updated_at: data['updated_at'],
        closed_at: data['closed_at'],
        user: data['user'] ? data['user']['login'] : nil,
        url: data['html_url']
      }
    else
      debug_log "  Error fetching GitHub data: #{response.body}"
      nil
    end
  rescue => e
    debug_log "  Exception: #{e.message}"
    nil
  end

  private

  def debug_log(message)
    puts "[DEBUG] #{message}" if @debug
  end
end
