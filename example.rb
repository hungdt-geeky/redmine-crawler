#!/usr/bin/env ruby

require_relative 'redmine_client'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
REDMINE_API_KEY = ENV['REDMINE_API_KEY'] || 'YOUR_API_KEY_HERE'

# Khởi tạo client
client = RedmineClient.new(REDMINE_URL, REDMINE_API_KEY)

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
