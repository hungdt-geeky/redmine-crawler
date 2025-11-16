# Redmine Crawler

Script Ruby để lấy thông tin từ Redmine API. Hỗ trợ lấy thông tin về issues, user stories, projects và users.

## Yêu cầu

- Ruby 2.5 trở lên
- API Key từ Redmine (hoặc Username/Password)

## Cài đặt

1. Clone repository:
```bash
git clone <repository-url>
cd redmine-crawler
```

2. Tạo file cấu hình `.env` từ template:
```bash
cp .env.example .env
```

3. Chỉnh sửa file `.env` và điền thông tin của bạn:
```
REDMINE_URL=https://dev.zigexn.vn
REDMINE_API_KEY=your_api_key_here
```

### Cách lấy API Key từ Redmine

1. Đăng nhập vào Redmine
2. Click vào tên người dùng ở góc trên bên phải
3. Chọn "My account"
4. Tìm phần "API access key" hoặc "Access keys"
5. Click "Show" để xem API key hoặc "Reset" để tạo mới
6. Copy API key và paste vào file `.env`

### Phương thức xác thực

Script hỗ trợ 2 phương thức xác thực:

**1. API Key (Khuyến nghị)**
```bash
export REDMINE_API_KEY=your_api_key_here
ruby example.rb
```

**2. Username/Password**
```bash
export REDMINE_USERNAME=your_username
export REDMINE_PASSWORD=your_password
ruby example.rb
```

### Chế độ Debug

Để xem chi tiết request/response và troubleshoot lỗi:

```bash
# Sử dụng environment variable
DEBUG=true REDMINE_API_KEY=your_key ruby example.rb

# Hoặc dùng option --debug (chỉ với get_user_story.rb)
REDMINE_API_KEY=your_key ruby get_user_story.rb -i 106864 --debug
```

## Sử dụng

### 1. Script đơn giản (example.rb)

Chạy các ví dụ cơ bản:

```bash
# Load API key từ file .env hoặc export trước
export REDMINE_API_KEY=your_api_key_here
ruby example.rb
```

### 2. Script nâng cao (get_user_story.rb)

Script này hỗ trợ nhiều tùy chọn để lấy thông tin issues:

#### Lấy thông tin một issue cụ thể:

```bash
# Lấy issue #106864
ruby get_user_story.rb -i 106864

# Hoặc với API key inline
REDMINE_API_KEY=your_key ruby get_user_story.rb -i 106864
```

#### Lấy danh sách issues:

```bash
# Lấy 10 issues mới nhất
ruby get_user_story.rb

# Lấy 20 issues mới nhất
ruby get_user_story.rb -l 20

# Lấy issues từ vị trí thứ 10
ruby get_user_story.rb -l 10 -o 10
```

#### Lọc issues theo điều kiện:

```bash
# Lọc theo project
ruby get_user_story.rb -p project_identifier

# Lọc theo tracker (User Story, Bug, Task...)
# Ví dụ: tracker_id = 2 cho User Story
ruby get_user_story.rb -t 2 -l 20

# Lọc theo status
# Ví dụ: status_id = 1 cho New
ruby get_user_story.rb -s 1

# Kết hợp nhiều điều kiện
ruby get_user_story.rb -p my_project -t 2 -s 1 -l 50
```

#### Xuất kết quả dạng JSON:

```bash
# Xuất issue dạng JSON
ruby get_user_story.rb -i 106864 --json

# Xuất danh sách issues dạng JSON
ruby get_user_story.rb -l 10 --json > issues.json
```

#### Các tùy chọn (options):

```
-i, --issue-id ID          Lấy thông tin issue theo ID
-p, --project PROJECT      Lấy issues theo project ID hoặc identifier
-t, --tracker TRACKER_ID   Lọc theo tracker ID
-s, --status STATUS_ID     Lọc theo status ID
-l, --limit LIMIT          Số lượng kết quả tối đa (mặc định: 10)
-o, --offset OFFSET        Bỏ qua số kết quả đầu tiên
    --json                 Xuất kết quả dạng JSON
-h, --help                 Hiển thị trợ giúp
```

### 3. Sử dụng RedmineClient class trong code của bạn

```ruby
require_relative 'redmine_client'

# Khởi tạo client
client = RedmineClient.new('https://dev.zigexn.vn', 'your_api_key')

# Lấy thông tin một issue
issue = client.get_issue(106864)
puts issue['issue']['subject']

# Lấy danh sách issues
issues = client.get_issues(limit: 10, tracker_id: 2)
issues['issues'].each do |issue|
  puts "#{issue['id']}: #{issue['subject']}"
end

# Lấy thông tin user
user = client.get_user(123)
puts user['user']['firstname']

# Lấy danh sách projects
projects = client.get_projects
projects['projects'].each do |project|
  puts project['name']
end
```

## Cấu trúc project

```
redmine-crawler/
├── redmine_client.rb      # Class chính để tương tác với Redmine API
├── example.rb             # Script ví dụ đơn giản
├── get_user_story.rb      # Script nâng cao với nhiều options
├── .env.example           # Template cho file cấu hình
└── README.md              # File này
```

## API Endpoints được hỗ trợ

- `GET /issues/:id.json` - Lấy thông tin chi tiết một issue
- `GET /issues.json` - Lấy danh sách issues với filter
- `GET /users/:id.json` - Lấy thông tin user
- `GET /projects.json` - Lấy danh sách projects

## Troubleshooting

### Lỗi 401 Unauthorized

Nếu bạn gặp lỗi này:
```
Lỗi: Failed to fetch issue: 401 - Unauthorized
```

**Nguyên nhân và giải pháp:**

1. **API Key chưa được thiết lập hoặc sai**
   - Kiểm tra xem bạn đã set `REDMINE_API_KEY` chưa
   - Chạy với debug mode để xem chi tiết: `DEBUG=true ruby example.rb`
   - Đảm bảo API key đúng bằng cách login vào Redmine và kiểm tra lại

2. **API Key đã hết hạn hoặc bị vô hiệu hóa**
   - Vào Redmine > My account > API access key
   - Click "Reset" để tạo key mới

3. **REST API chưa được bật trên server**
   - Liên hệ admin Redmine để bật REST API
   - Vào Administration > Settings > API > Enable REST web service

4. **Thử dùng Username/Password thay vì API Key**
   ```bash
   REDMINE_USERNAME=your_username REDMINE_PASSWORD=your_password ruby example.rb
   ```

### Lỗi SSL Certificate

Nếu gặp lỗi SSL:
```
SSL_connect returned=1 errno=0 state=error: certificate verify failed
```

Script đã tự động tắt SSL verification (dành cho self-signed certificates). Nếu vẫn gặp lỗi, kiểm tra xem server có đang chạy HTTPS không.

### Xem chi tiết lỗi

Luôn sử dụng debug mode khi gặp vấn đề:
```bash
DEBUG=true REDMINE_API_KEY=your_key ruby get_user_story.rb -i 106864
```

Debug mode sẽ hiển thị:
- URL được request
- Headers được gửi
- Response status và headers
- Response body khi có lỗi

## Tham khảo

- [Redmine REST API Documentation](https://www.redmine.org/projects/redmine/wiki/Rest_api)
- [Redmine Issues API](https://www.redmine.org/projects/redmine/wiki/Rest_Issues)

## License

MIT