#!/usr/bin/env ruby

# Auto-load .env file if exists
require_relative 'dotenv'
require_relative 'redmine_client'
require_relative 'github_client'
require 'optparse'
require 'csv'

# Cấu hình
REDMINE_URL = ENV['REDMINE_URL'] || 'https://dev.zigexn.vn'
HTTP_USERNAME = ENV['HTTP_USERNAME']
HTTP_PASSWORD = ENV['HTTP_PASSWORD']
REDMINE_API_KEY = ENV['REDMINE_API_KEY']
GITHUB_TOKEN = ENV['GITHUB_TOKEN']
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

# Khởi tạo GitHub client (optional)
github_client = nil
if GITHUB_TOKEN && !GITHUB_TOKEN.empty?
  github_client = GitHubClient.new(GITHUB_TOKEN, debug: debug_mode)
  puts "GitHub integration enabled" if debug_mode
end

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

def format_issue_data(issue, client: nil, github_client: nil, include_subtasks: true)
  difficulty = get_custom_field(issue, 'Difficulty Level')
  issue_link = get_custom_field(issue, 'JP Request')  # GitHub Issue link
  pr_link = get_custom_field(issue, 'PR')              # GitHub PR link

  diff_data = calculate_diff_estimate(issue)

  data = {
    id: issue['id'],
    subject: issue['subject'],
    tracker: issue['tracker'] ? issue['tracker']['name'] : 'N/A',
    status: issue['status'] ? issue['status']['name'] : 'N/A',
    priority: issue['priority'] ? issue['priority']['name'] : 'N/A',
    assigned_to: issue['assigned_to'] ? issue['assigned_to']['name'] : 'Unassigned',
    difficulty_level: difficulty || 'N/A',
    issue_link: issue_link || 'N/A',
    pr_link: pr_link || 'N/A',
    estimated_hours: diff_data[:estimated],
    spent_hours: diff_data[:spent],
    diff_estimate: diff_data[:diff],
    start_date: issue['start_date'],
    due_date: issue['due_date'],
    done_ratio: issue['done_ratio'] || 0,
    created_on: issue['created_on'],
    updated_on: issue['updated_on']
  }

  # Fetch GitHub Issue info if issue link exists
  if github_client && issue_link && issue_link != 'N/A' && issue_link.include?('github.com')
    issue_info = github_client.get_pr_info(issue_link)
    if issue_info
      data[:issue_comments] = issue_info[:comments]
      data[:issue_state] = issue_info[:state]
    else
      data[:issue_comments] = 'N/A'
      data[:issue_state] = 'N/A'
    end
  else
    data[:issue_comments] = 'N/A'
    data[:issue_state] = 'N/A'
  end

  # Fetch GitHub PR info if PR link exists
  if github_client && pr_link && pr_link != 'N/A' && pr_link.include?('github.com')
    pr_info = github_client.get_pr_info(pr_link)
    if pr_info
      data[:pr_comments] = pr_info[:comments]
      data[:pr_state] = pr_info[:state]
    else
      data[:pr_comments] = 'N/A'
      data[:pr_state] = 'N/A'
    end
  else
    data[:pr_comments] = 'N/A'
    data[:pr_state] = 'N/A'
  end

  # Lấy thêm thông tin cho Testing subtasks (bắt đầu với "4.")
  if issue['subject'] && issue['subject'].strip.start_with?('4.')
    data[:test_cases] = get_custom_field(issue, 'Number of test cases') || '0'
    data[:stg_bugs_vn] = get_custom_field(issue, 'STG Bugs (VN)') || '0'
    data[:stg_bugs_jp] = get_custom_field(issue, 'STG Bugs (JP)') || '0'
    data[:production_bugs] = get_custom_field(issue, 'Production Bugs') || '0'
  end

  # Lấy subtasks nếu có (recursively)
  # NOTE: Redmine API chỉ trả về partial data cho children (id, tracker, subject)
  # Cần fetch full data cho mỗi subtask
  if include_subtasks && issue['children'] && client
    data[:subtasks] = issue['children'].map do |child|
      # Fetch full data cho subtask
      begin
        child_full_data = client.get_issue(child['id'], include: 'children')
        if child_full_data['issue']
          # RECURSIVE: Lấy cả subtasks của subtask này (nested subtasks)
          format_issue_data(child_full_data['issue'], client: client, github_client: github_client, include_subtasks: true)
        else
          # Fallback nếu không fetch được
          nil
        end
      rescue => e
        # Skip nếu có lỗi
        nil
      end
    end.compact  # Remove nil values
  end

  data
end

# Helper function to recursively print subtasks with proper indentation
def print_subtasks(subtasks, indent_level = 1)
  return unless subtasks && !subtasks.empty?

  subtasks.each do |subtask|
    sub_est_spent = "#{subtask[:estimated_hours]}/#{subtask[:spent_hours]}"
    sub_diff = subtask[:diff_estimate] >= 0 ? "+#{subtask[:diff_estimate]}" : subtask[:diff_estimate].to_s

    # Adjust subject width based on indentation level
    indent = "  " + ("  " * indent_level)
    subject_width = 40 - (indent_level * 2)
    subject_width = 20 if subject_width < 20 # Minimum width

    puts "#{indent}├─ #%-6s | %-#{subject_width}s | %-10s | %-8s | %s" % [
      subtask[:id],
      subtask[:subject][0..(subject_width - 1)],
      subtask[:status][0..9],
      sub_est_spent,
      sub_diff
    ]

    # Hiển thị thông tin testing cho subtasks bắt đầu với "4."
    if subtask[:test_cases]
      puts "#{indent}   Testing Info: Cases=#{subtask[:test_cases]} | STG(VN)=#{subtask[:stg_bugs_vn]} | STG(JP)=#{subtask[:stg_bugs_jp]} | Prod=#{subtask[:production_bugs]}"
    end

    # Recursively print nested subtasks with increased indentation
    if subtask[:subtasks] && !subtask[:subtasks].empty?
      print_subtasks(subtask[:subtasks], indent_level + 1)
    end
  end
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

    # Print Issue link if exists
    if data[:issue_link] && data[:issue_link] != 'N/A' && !data[:issue_link].empty?
      issue_info = "  Issue: #{data[:issue_link]}"
      if data[:issue_comments] && data[:issue_comments] != 'N/A'
        issue_info += " | Comments: #{data[:issue_comments]} | State: #{data[:issue_state]}"
      end
      puts issue_info
    end

    # Print PR link (always show, use "None" if empty)
    if data[:pr_link] && data[:pr_link] != 'N/A' && !data[:pr_link].empty?
      pr_info = "  PR: #{data[:pr_link]}"
      if data[:pr_comments] && data[:pr_comments] != 'N/A'
        pr_info += " | Comments: #{data[:pr_comments]} | State: #{data[:pr_state]}"
      end
      puts pr_info
    else
      puts "  PR: None"
    end

    # Print subtasks recursively
    if data[:subtasks] && !data[:subtasks].empty?
      total_subtasks = count_total_subtasks(data[:subtasks])
      puts "  Subtasks (#{data[:subtasks].length} direct, #{total_subtasks} total):"
      print_subtasks(data[:subtasks])
    end

    puts "-" * 150
  end

  puts "Total: #{issues_data.length} issues"
  puts "=" * 150
end

# Helper function to count total subtasks including nested ones
def count_total_subtasks(subtasks)
  return 0 unless subtasks

  count = subtasks.length
  subtasks.each do |subtask|
    count += count_total_subtasks(subtask[:subtasks]) if subtask[:subtasks]
  end
  count
end

# Helper function to recursively flatten subtasks for CSV
def flatten_subtasks_for_csv(subtasks, parent_id, result = [])
  return result unless subtasks

  subtasks.each do |subtask|
    result << {data: subtask, parent_id: parent_id}
    # Recursively add nested subtasks
    flatten_subtasks_for_csv(subtask[:subtasks], subtask[:id], result) if subtask[:subtasks]
  end
  result
end

def print_csv(issues_data)
  csv_string = CSV.generate do |csv|
    # Header
    csv << [
      'ID', 'Subject', 'Tracker', 'Status', 'Priority', 'Assigned To',
      'Difficulty Level',
      'Issue Link', 'Issue Comments', 'Issue State',
      'PR Link', 'PR Comments', 'PR State',
      'Estimated Hours', 'Spent Hours', 'Diff (Spent-Est)',
      'Start Date', 'Due Date', 'Done %',
      'Test Cases', 'STG Bugs (VN)', 'STG Bugs (JP)', 'Production Bugs',
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
        data[:issue_link] || '',
        data[:issue_comments] || '',
        data[:issue_state] || '',
        data[:pr_link] || '',
        data[:pr_comments] || '',
        data[:pr_state] || '',
        data[:estimated_hours],
        data[:spent_hours],
        data[:diff_estimate],
        data[:start_date],
        data[:due_date],
        data[:done_ratio],
        data[:test_cases] || '',
        data[:stg_bugs_vn] || '',
        data[:stg_bugs_jp] || '',
        data[:production_bugs] || '',
        data[:created_on],
        data[:updated_on],
        'No',
        ''
      ]

      # Add all subtasks (recursively flattened)
      if data[:subtasks]
        flattened = flatten_subtasks_for_csv(data[:subtasks], data[:id])
        flattened.each do |item|
          subtask = item[:data]
          csv << [
            subtask[:id],
            subtask[:subject],
            subtask[:tracker],
            subtask[:status],
            subtask[:priority],
            subtask[:assigned_to],
            subtask[:difficulty_level],
            subtask[:issue_link] || '',
            subtask[:issue_comments] || '',
            subtask[:issue_state] || '',
            subtask[:pr_link] || '',
            subtask[:pr_comments] || '',
            subtask[:pr_state] || '',
            subtask[:estimated_hours],
            subtask[:spent_hours],
            subtask[:diff_estimate],
            subtask[:start_date],
            subtask[:due_date],
            subtask[:done_ratio],
            subtask[:test_cases] || '',
            subtask[:stg_bugs_vn] || '',
            subtask[:stg_bugs_jp] || '',
            subtask[:production_bugs] || '',
            subtask[:created_on],
            subtask[:updated_on],
            'Yes',
            item[:parent_id]
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

  formatted = format_issue_data(issue_data['issue'], client: client, github_client: github_client, include_subtasks: options[:include_subtasks])

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
    format_issue_data(issue, client: client, github_client: github_client, include_subtasks: options[:include_subtasks])
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
