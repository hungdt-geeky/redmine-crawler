#!/usr/bin/env ruby

# Auto-load .env file if exists
require_relative 'dotenv'
require_relative 'redmine_client'
require 'optparse'
require 'csv'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
HTTP_USERNAME = ENV['HTTP_USERNAME']
HTTP_PASSWORD = ENV['HTTP_PASSWORD']
REDMINE_API_KEY = ENV['REDMINE_API_KEY']
DEBUG = ENV['DEBUG'] == 'true' || ENV['DEBUG'] == '1'

# Parse command line arguments
options = {
  format: 'table',
  include_subtasks: true
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby crawler.rb [options]"

  opts.on("-i", "--issue-id ID", Integer, "ID của issue cần crawl") do |id|
    options[:issue_id] = id
  end

  opts.on("-p", "--project PROJECT", "Crawl tất cả issues trong project") do |project|
    options[:project] = project
  end

  opts.on("-t", "--tracker TRACKER_ID", Integer, "Lọc theo tracker ID") do |tracker|
    options[:tracker_id] = tracker
  end

  opts.on("-s", "--status STATUS_ID", Integer, "Lọc theo status ID") do |status|
    options[:status_id] = status
  end

  opts.on("-l", "--limit LIMIT", Integer, "Số lượng issues tối đa (mặc định: 25)") do |limit|
    options[:limit] = limit
  end

  opts.on("-o", "--offset OFFSET", Integer, "Bỏ qua số issues đầu tiên") do |offset|
    options[:offset] = offset
  end

  opts.on("-f", "--format FORMAT", ["table", "csv", "json"], "Format output: table, csv, json (mặc định: table)") do |format|
    options[:format] = format
  end

  opts.on("--no-subtasks", "Không hiển thị subtasks") do
    options[:include_subtasks] = false
  end

  opts.on("--debug", "Bật chế độ debug") do
    options[:debug] = true
  end

  opts.on("-h", "--help", "Hiển thị trợ giúp") do
    puts opts
    puts ""
    puts "Examples:"
    puts "  # Crawl một issue cụ thể"
    puts "  ruby crawler.rb -i 106864"
    puts ""
    puts "  # Crawl tất cả User Stories trong project"
    puts "  ruby crawler.rb -p my_project -t 2"
    puts ""
    puts "  # Xuất ra CSV"
    puts "  ruby crawler.rb -t 2 -l 50 -f csv > output.csv"
    puts ""
    exit
  end
end.parse!

# Kiểm tra thông tin xác thực
if REDMINE_API_KEY.nil?
  puts "ERROR: Chưa cấu hình REDMINE_API_KEY trong file .env"
  puts "Vui lòng tạo file .env và thêm REDMINE_API_KEY=your_key"
  exit 1
end

# Khởi tạo client
debug_mode = DEBUG || options[:debug]

client = RedmineClient.new(REDMINE_URL, REDMINE_API_KEY, {
  debug: debug_mode,
  verify_ssl: false,
  http_username: HTTP_USERNAME,
  http_password: HTTP_PASSWORD
})

# Helper functions
def get_custom_field(issue, field_name)
  return nil unless issue['custom_fields']

  field = issue['custom_fields'].find { |f| f['name'] == field_name }
  field ? field['value'] : nil
end

def calculate_diff_estimate(issue)
  estimated = issue['estimated_hours'].to_f
  spent = issue['spent_hours'].to_f
  diff = spent - estimated

  {
    estimated: estimated,
    spent: spent,
    diff: diff
  }
end

def format_issue_data(issue, include_subtasks: true)
  difficulty = get_custom_field(issue, 'Difficulty Level')
  pr_link = get_custom_field(issue, 'JP Request') || get_custom_field(issue, 'PR')

  diff_data = calculate_diff_estimate(issue)

  data = {
    id: issue['id'],
    subject: issue['subject'],
    tracker: issue['tracker']['name'],
    status: issue['status']['name'],
    priority: issue['priority']['name'],
    assigned_to: issue['assigned_to'] ? issue['assigned_to']['name'] : 'Unassigned',
    difficulty_level: difficulty || 'N/A',
    pr_link: pr_link || 'N/A',
    estimated_hours: diff_data[:estimated],
    spent_hours: diff_data[:spent],
    diff_estimate: diff_data[:diff],
    start_date: issue['start_date'],
    due_date: issue['due_date'],
    done_ratio: issue['done_ratio'],
    created_on: issue['created_on'],
    updated_on: issue['updated_on']
  }

  # Lấy subtasks nếu có
  if include_subtasks && issue['children']
    data[:subtasks] = issue['children'].map do |child|
      format_issue_data(child, include_subtasks: false)
    end
  end

  data
end

def print_table(issues_data)
  puts "=" * 150
  puts "%-8s | %-50s | %-10s | %-10s | %-8s | %-10s | %-10s | %-8s" % [
    "ID", "Subject", "Status", "Assigned", "Diff Lv", "Est/Spent", "Diff", "Done%"
  ]
  puts "=" * 150

  issues_data.each do |data|
    est_spent = "#{data[:estimated_hours]}/#{data[:spent_hours]}"
    diff = data[:diff_estimate] >= 0 ? "+#{data[:diff_estimate]}" : data[:diff_estimate].to_s

    puts "%-8s | %-50s | %-10s | %-10s | %-8s | %-10s | %-8s | %-8s" % [
      data[:id],
      data[:subject][0..48],
      data[:status][0..9],
      data[:assigned_to][0..9],
      data[:difficulty_level],
      est_spent,
      diff,
      "#{data[:done_ratio]}%"
    ]

    # Print PR link if exists
    if data[:pr_link] && data[:pr_link] != 'N/A'
      puts "  PR: #{data[:pr_link]}"
    end

    # Print subtasks
    if data[:subtasks] && !data[:subtasks].empty?
      puts "  Subtasks (#{data[:subtasks].length}):"
      data[:subtasks].each do |subtask|
        sub_est_spent = "#{subtask[:estimated_hours]}/#{subtask[:spent_hours]}"
        sub_diff = subtask[:diff_estimate] >= 0 ? "+#{subtask[:diff_estimate]}" : subtask[:diff_estimate].to_s

        puts "    ├─ #%-6s | %-40s | %-10s | %-8s | %s" % [
          subtask[:id],
          subtask[:subject][0..38],
          subtask[:status][0..9],
          sub_est_spent,
          sub_diff
        ]
      end
    end

    puts "-" * 150
  end

  puts "Total: #{issues_data.length} issues"
  puts "=" * 150
end

def print_csv(issues_data)
  csv_string = CSV.generate do |csv|
    # Header
    csv << [
      'ID', 'Subject', 'Tracker', 'Status', 'Priority', 'Assigned To',
      'Difficulty Level', 'PR Link', 'Estimated Hours', 'Spent Hours',
      'Diff (Spent-Est)', 'Start Date', 'Due Date', 'Done %',
      'Created On', 'Updated On', 'Is Subtask', 'Parent ID'
    ]

    # Data rows
    issues_data.each do |data|
      csv << [
        data[:id],
        data[:subject],
        data[:tracker],
        data[:status],
        data[:priority],
        data[:assigned_to],
        data[:difficulty_level],
        data[:pr_link],
        data[:estimated_hours],
        data[:spent_hours],
        data[:diff_estimate],
        data[:start_date],
        data[:due_date],
        data[:done_ratio],
        data[:created_on],
        data[:updated_on],
        'No',
        ''
      ]

      # Add subtasks
      if data[:subtasks]
        data[:subtasks].each do |subtask|
          csv << [
            subtask[:id],
            subtask[:subject],
            subtask[:tracker],
            subtask[:status],
            subtask[:priority],
            subtask[:assigned_to],
            subtask[:difficulty_level],
            subtask[:pr_link],
            subtask[:estimated_hours],
            subtask[:spent_hours],
            subtask[:diff_estimate],
            subtask[:start_date],
            subtask[:due_date],
            subtask[:done_ratio],
            subtask[:created_on],
            subtask[:updated_on],
            'Yes',
            data[:id]
          ]
        end
      end
    end
  end

  puts csv_string
end

def print_json(issues_data)
  require 'json'
  puts JSON.pretty_generate(issues_data)
end

# Main logic
if options[:issue_id]
  # Crawl một issue cụ thể
  puts "Fetching issue ##{options[:issue_id]}..." if options[:format] == 'table'

  issue_data = client.get_issue(options[:issue_id], include: 'children,attachments')

  if issue_data['error']
    puts "Error: #{issue_data['error']}"
    exit 1
  end

  formatted = format_issue_data(issue_data['issue'], include_subtasks: options[:include_subtasks])

  case options[:format]
  when 'csv'
    print_csv([formatted])
  when 'json'
    print_json([formatted])
  else
    print_table([formatted])
  end
else
  # Crawl danh sách issues
  params = {
    limit: options[:limit] || 25,
    sort: 'updated_on:desc',
    include: 'children'
  }

  params[:offset] = options[:offset] if options[:offset]
  params[:project_id] = options[:project] if options[:project]
  params[:tracker_id] = options[:tracker_id] if options[:tracker_id]
  params[:status_id] = options[:status_id] if options[:status_id]

  puts "Fetching issues..." if options[:format] == 'table'

  issues_data = client.get_issues(params)

  if issues_data['error']
    puts "Error: #{issues_data['error']}"
    exit 1
  end

  formatted_issues = issues_data['issues'].map do |issue|
    format_issue_data(issue, include_subtasks: options[:include_subtasks])
  end

  case options[:format]
  when 'csv'
    print_csv(formatted_issues)
  when 'json'
    print_json(formatted_issues)
  else
    print_table(formatted_issues)
  end
end
