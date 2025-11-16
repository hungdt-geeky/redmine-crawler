#!/usr/bin/env ruby

require_relative 'redmine_client'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
REDMINE_API_KEY = ENV['REDMINE_API_KEY']
REDMINE_USERNAME = ENV['REDMINE_USERNAME']
REDMINE_PASSWORD = ENV['REDMINE_PASSWORD']
DEBUG = ENV['DEBUG'] == 'true' || ENV['DEBUG'] == '1'

# Kiểm tra xem có thông tin đăng nhập không
if REDMINE_API_KEY.nil? && (REDMINE_USERNAME.nil? || REDMINE_PASSWORD.nil?)
  puts "=" * 80
  puts "ERROR: Chưa cấu hình thông tin xác thực!"
  puts "=" * 80
  puts ""
  puts "Bạn cần thiết lập một trong hai phương thức xác thực sau:"
  puts ""
  puts "PHƯƠNG THỨC 1: Dùng API Key (Khuyến nghị)"
  puts "  1. Đăng nhập vào Redmine: #{REDMINE_URL}"
  puts "  2. Click vào tên người dùng ở góc trên phải > 'My account'"
  puts "  3. Tìm phần 'API access key' hoặc 'Access keys'"
  puts "  4. Click 'Show' để xem hoặc 'Reset' để tạo key mới"
  puts "  5. Chạy lại script với API key:"
  puts ""
  puts "     REDMINE_API_KEY=your_api_key_here ruby example.rb"
  puts ""
  puts "PHƯƠNG THỨC 2: Dùng Username/Password"
  puts "  Chạy script với username và password:"
  puts ""
  puts "     REDMINE_USERNAME=your_username REDMINE_PASSWORD=your_password ruby example.rb"
  puts ""
  puts "CHẾ ĐỘ DEBUG:"
  puts "  Để xem chi tiết request/response, thêm DEBUG=true:"
  puts ""
  puts "     DEBUG=true REDMINE_API_KEY=your_key ruby example.rb"
  puts ""
  puts "=" * 80
  exit 1
end

# Khởi tạo client
if REDMINE_API_KEY
  puts "Đang kết nối với Redmine bằng API Key..."
  client = RedmineClient.new(REDMINE_URL, REDMINE_API_KEY, {
    debug: DEBUG,
    verify_ssl: false  # Tắt SSL verification cho self-signed certificates
  })
else
  puts "Đang kết nối với Redmine bằng Username/Password..."
  client = RedmineClient.new(REDMINE_URL, nil, {
    username: REDMINE_USERNAME,
    password: REDMINE_PASSWORD,
    debug: DEBUG,
    verify_ssl: false
  })
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
