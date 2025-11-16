#!/usr/bin/env ruby

require_relative 'redmine_client'
require 'optparse'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
REDMINE_API_KEY = ENV['REDMINE_API_KEY']

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby get_user_story.rb [options]"

  opts.on("-i", "--issue-id ID", Integer, "Lấy thông tin issue theo ID") do |id|
    options[:issue_id] = id
  end

  opts.on("-p", "--project PROJECT", "Lấy issues theo project ID hoặc identifier") do |project|
    options[:project] = project
  end

  opts.on("-t", "--tracker TRACKER_ID", Integer, "Lọc theo tracker ID") do |tracker|
    options[:tracker_id] = tracker
  end

  opts.on("-s", "--status STATUS_ID", Integer, "Lọc theo status ID") do |status|
    options[:status_id] = status
  end

  opts.on("-l", "--limit LIMIT", Integer, "Số lượng kết quả tối đa (mặc định: 10)") do |limit|
    options[:limit] = limit
  end

  opts.on("-o", "--offset OFFSET", Integer, "Bỏ qua số kết quả đầu tiên") do |offset|
    options[:offset] = offset
  end

  opts.on("--json", "Xuất kết quả dạng JSON") do
    options[:json] = true
  end

  opts.on("-h", "--help", "Hiển thị trợ giúp") do
    puts opts
    exit
  end
end.parse!

# Kiểm tra API key
if REDMINE_API_KEY.nil? || REDMINE_API_KEY.empty?
  puts "ERROR: REDMINE_API_KEY chưa được thiết lập!"
  puts "Vui lòng:"
  puts "  1. Copy file .env.example thành .env"
  puts "  2. Điền API key của bạn vào file .env"
  puts "  3. Chạy lại script với: REDMINE_API_KEY=your_key ruby get_user_story.rb"
  exit 1
end

# Khởi tạo client
client = RedmineClient.new(REDMINE_URL, REDMINE_API_KEY)

def print_issue(issue, json_format = false)
  if json_format
    puts JSON.pretty_generate(issue)
  else
    puts "=" * 80
    puts "Issue ##{issue['id']}: #{issue['subject']}"
    puts "=" * 80
    puts "Project:      #{issue['project']['name']}" if issue['project']
    puts "Tracker:      #{issue['tracker']['name']}" if issue['tracker']
    puts "Status:       #{issue['status']['name']}" if issue['status']
    puts "Priority:     #{issue['priority']['name']}" if issue['priority']
    puts "Author:       #{issue['author']['name']}" if issue['author']
    puts "Assigned to:  #{issue['assigned_to']['name']}" if issue['assigned_to']
    puts "Start date:   #{issue['start_date']}" if issue['start_date']
    puts "Due date:     #{issue['due_date']}" if issue['due_date']
    puts "Done ratio:   #{issue['done_ratio']}%" if issue['done_ratio']
    puts "Created on:   #{issue['created_on']}"
    puts "Updated on:   #{issue['updated_on']}"

    if issue['description'] && !issue['description'].empty?
      puts "\nDescription:"
      puts "-" * 80
      puts issue['description']
    end

    if issue['custom_fields'] && !issue['custom_fields'].empty?
      puts "\nCustom Fields:"
      puts "-" * 80
      issue['custom_fields'].each do |field|
        value = field['value'].is_a?(Array) ? field['value'].join(', ') : field['value']
        puts "  #{field['name']}: #{value}" unless value.to_s.empty?
      end
    end

    if issue['attachments'] && !issue['attachments'].empty?
      puts "\nAttachments:"
      puts "-" * 80
      issue['attachments'].each do |attachment|
        puts "  - #{attachment['filename']} (#{attachment['filesize']} bytes)"
        puts "    #{attachment['content_url']}"
      end
    end

    if issue['journals'] && !issue['journals'].empty?
      puts "\nHistory (#{issue['journals'].length} entries):"
      puts "-" * 80
      issue['journals'].each do |journal|
        next if journal['notes'].to_s.empty? && journal['details'].to_s.empty?

        puts "\n[#{journal['created_on']}] #{journal['user']['name']}"

        if journal['details'] && !journal['details'].empty?
          journal['details'].each do |detail|
            puts "  Changed #{detail['name']}: #{detail['old_value']} → #{detail['new_value']}"
          end
        end

        puts "  #{journal['notes']}" unless journal['notes'].to_s.empty?
      end
    end

    puts "=" * 80
    puts ""
  end
end

def print_issues_list(issues, total_count, json_format = false)
  if json_format
    puts JSON.pretty_generate({
      'total_count' => total_count,
      'issues' => issues
    })
  else
    puts "\nTổng số: #{total_count} issues"
    puts "Hiển thị: #{issues.length} issues\n"
    puts "=" * 80

    issues.each do |issue|
      status_marker = case issue['status']['name']
                      when /New|Mới/ then '🆕'
                      when /In Progress|Đang xử lý/ then '🔄'
                      when /Resolved|Đã giải quyết/ then '✅'
                      when /Closed|Đã đóng/ then '🔒'
                      else '📌'
                      end

      puts "#{status_marker} ##{issue['id']} - #{issue['subject']}"
      puts "   Tracker: #{issue['tracker']['name']}" if issue['tracker']
      puts "   Status: #{issue['status']['name']}" if issue['status']
      puts "   Assigned: #{issue['assigned_to']['name']}" if issue['assigned_to']
      puts "   Updated: #{issue['updated_on']}"
      puts ""
    end

    puts "=" * 80
  end
end

# Xử lý theo options
if options[:issue_id]
  # Lấy thông tin một issue cụ thể với include để có đầy đủ thông tin
  issue_data = client.get_issue(options[:issue_id])

  if issue_data['error']
    puts "Lỗi: #{issue_data['error']}"
    exit 1
  else
    print_issue(issue_data['issue'], options[:json])
  end
else
  # Lấy danh sách issues
  params = {
    limit: options[:limit] || 10,
    sort: 'updated_on:desc'
  }

  params[:offset] = options[:offset] if options[:offset]
  params[:project_id] = options[:project] if options[:project]
  params[:tracker_id] = options[:tracker_id] if options[:tracker_id]
  params[:status_id] = options[:status_id] if options[:status_id]

  issues_data = client.get_issues(params)

  if issues_data['error']
    puts "Lỗi: #{issues_data['error']}"
    exit 1
  else
    print_issues_list(issues_data['issues'], issues_data['total_count'], options[:json])
  end
end
