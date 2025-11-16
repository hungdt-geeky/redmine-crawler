#!/usr/bin/env ruby

require_relative 'redmine_client'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
HTTP_USERNAME = ENV['HTTP_USERNAME']
HTTP_PASSWORD = ENV['HTTP_PASSWORD']
REDMINE_API_KEY = ENV['REDMINE_API_KEY']
REDMINE_USERNAME = ENV['REDMINE_USERNAME']
REDMINE_PASSWORD = ENV['REDMINE_PASSWORD']
DEBUG = ENV['DEBUG'] == 'true' || ENV['DEBUG'] == '1'

# Kiểm tra xem có thông tin đăng nhập không
if REDMINE_API_KEY.nil? && (REDMINE_USERNAME.nil? || REDMINE_PASSWORD.nil?)
  puts "=" * 80
  puts "ERROR: Chưa cấu hình thông tin xác thực Redmine!"
  puts "=" * 80
  puts ""
  puts "Website này có HTTP Basic Auth protection. Bạn cần cấu hình:"
  puts ""
  puts "1. HTTP BASIC AUTH (bắt buộc - để qua nginx):"
  puts "   HTTP_USERNAME=your_http_user HTTP_PASSWORD=your_http_pass"
  puts ""
  puts "2. REDMINE AUTHENTICATION (chọn một):"
  puts ""
  puts "   PHƯƠNG THỨC A: API Key (Khuyến nghị)"
  puts "     - Lấy API key từ Redmine > My account > API access key"
  puts "     - Chạy:"
  puts "       HTTP_USERNAME=user HTTP_PASSWORD=pass REDMINE_API_KEY=key ruby example.rb"
  puts ""
  puts "   PHƯƠNG THỨC B: Username/Password"
  puts "     HTTP_USERNAME=user HTTP_PASSWORD=pass REDMINE_USERNAME=user REDMINE_PASSWORD=pass ruby example.rb"
  puts ""
  puts "CHẾ ĐỘ DEBUG:"
  puts "  Thêm DEBUG=true để xem chi tiết:"
  puts "    DEBUG=true HTTP_USERNAME=... HTTP_PASSWORD=... REDMINE_API_KEY=... ruby example.rb"
  puts ""
  puts "=" * 80
  exit 1
end

# Khởi tạo client options
client_options = {
  debug: DEBUG,
  verify_ssl: false,  # Tắt SSL verification cho self-signed certificates
  http_username: HTTP_USERNAME,
  http_password: HTTP_PASSWORD
}

# Khởi tạo client
if REDMINE_API_KEY
  puts "Đang kết nối với Redmine..."
  client = RedmineClient.new(REDMINE_URL, REDMINE_API_KEY, client_options)
else
  puts "Đang kết nối với Redmine..."
  client = RedmineClient.new(REDMINE_URL, nil, client_options.merge({
    username: REDMINE_USERNAME,
    password: REDMINE_PASSWORD
  }))
end

puts "Phương thức xác thực: #{client.auth_method}"
puts ""

# Ví dụ 1: Lấy thông tin một issue cụ thể
puts "=" * 80
puts "VÍ DỤ 1: LẤY THÔNG TIN ISSUE #106864"
puts "=" * 80

issue_data = client.get_issue(106864)

if issue_data['error']
  puts "Lỗi: #{issue_data['error']}"
else
  issue = issue_data['issue']
  puts "\nID: #{issue['id']}"
  puts "Subject: #{issue['subject']}"
  puts "Project: #{issue['project']['name']}" if issue['project']
  puts "Tracker: #{issue['tracker']['name']}" if issue['tracker']
  puts "Status: #{issue['status']['name']}" if issue['status']
  puts "Priority: #{issue['priority']['name']}" if issue['priority']
  puts "Author: #{issue['author']['name']}" if issue['author']
  puts "Assigned to: #{issue['assigned_to']['name']}" if issue['assigned_to']
  puts "Created on: #{issue['created_on']}"
  puts "Updated on: #{issue['updated_on']}"
  puts "Description: #{issue['description']}" if issue['description']

  # Hiển thị custom fields nếu có
  if issue['custom_fields'] && !issue['custom_fields'].empty?
    puts "\nCustom Fields:"
    issue['custom_fields'].each do |field|
      puts "  - #{field['name']}: #{field['value']}"
    end
  end
end

# Ví dụ 2: Lấy danh sách issues trong project
puts "\n" + "=" * 80
puts "VÍ DỤ 2: LẤY DANH SÁCH ISSUES"
puts "=" * 80

# Lấy 5 issues mới nhất
issues_data = client.get_issues(limit: 5, sort: 'updated_on:desc')

if issues_data['error']
  puts "Lỗi: #{issues_data['error']}"
else
  puts "\nTổng số issues: #{issues_data['total_count']}"
  puts "\nDanh sách #{issues_data['issues'].length} issues mới nhất:\n"

  issues_data['issues'].each do |issue|
    puts "  ##{issue['id']} - #{issue['subject']}"
    puts "    Status: #{issue['status']['name']}"
    puts "    Updated: #{issue['updated_on']}"
    puts ""
  end
end

# Ví dụ 3: Lấy issues theo filter (ví dụ: chỉ lấy User Story)
puts "=" * 80
puts "VÍ DỤ 3: LẤY ISSUES THEO TRACKER (User Story)"
puts "=" * 80

# Note: Bạn cần biết tracker_id của "User Story" trong hệ thống Redmine của bạn
# Thường tracker_id có thể là 2, 3, 4... tùy thuộc vào cấu hình
# Ví dụ này sẽ lấy issues với tracker_id = 2
filtered_issues = client.get_issues(tracker_id: 2, limit: 5)

if filtered_issues['error']
  puts "Lỗi: #{filtered_issues['error']}"
else
  puts "\nTìm thấy #{filtered_issues['total_count']} User Stories"
  puts "\nDanh sách 5 User Stories mới nhất:\n"

  filtered_issues['issues'].each do |issue|
    puts "  ##{issue['id']} - #{issue['subject']}"
    puts "    Tracker: #{issue['tracker']['name']}"
    puts "    Status: #{issue['status']['name']}"
    puts ""
  end
end
