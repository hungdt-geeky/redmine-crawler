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

2. Tạo file cấu hình `.env`:
```bash
# Option 1: Copy từ template
cp .env.example .env

# Option 2: Tạo trực tiếp (nếu đã có file .env trong repo)
# File .env sẽ được tự động load khi chạy script
```

3. Chỉnh sửa file `.env` và điền thông tin của bạn:
```
REDMINE_URL=https://dev.zigexn.vn

# HTTP Basic Auth (bắt buộc cho dev.zigexn.vn)
HTTP_USERNAME=your_http_username
HTTP_PASSWORD=your_http_password

# Redmine API Key
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

Website `dev.zigexn.vn` có **2 lớp bảo mật**:

1. **HTTP Basic Authentication** (nginx layer) - BẮT BUỘC
2. **Redmine Authentication** (application layer) - CHỌN MỘT

#### Lớp 1: HTTP Basic Auth (nginx)

```bash
export HTTP_USERNAME=your_http_username
export HTTP_PASSWORD=your_http_password
```

#### Lớp 2: Redmine Authentication (chọn một)

**Option A: API Key (Khuyến nghị)**
```bash
export REDMINE_API_KEY=your_api_key_here
```

**Option B: Username/Password**
```bash
export REDMINE_USERNAME=your_username
export REDMINE_PASSWORD=your_password
```

#### Ví dụ sử dụng đầy đủ:

```bash
# Với API Key (khuyến nghị)
HTTP_USERNAME=httpuser HTTP_PASSWORD=httppass REDMINE_API_KEY=apikey ruby example.rb

# Với Username/Password
HTTP_USERNAME=httpuser HTTP_PASSWORD=httppass REDMINE_USERNAME=user REDMINE_PASSWORD=pass ruby example.rb
```

### Auto-load .env file

Script tự động load file `.env` nếu có. Bạn không cần `source .env` nữa!

```bash
# Sau khi đã cấu hình .env, chỉ cần chạy trực tiếp:
ruby example.rb
ruby get_user_story.rb -i 106864

# File .env sẽ được tự động load
# Environment variables từ command line vẫn có độ ưu tiên cao hơn
```

### Chế độ Debug

Để xem chi tiết request/response và troubleshoot lỗi:

```bash
# Cách 1: Thêm DEBUG=true vào file .env
# Chỉnh sửa .env:
# DEBUG=true

# Cách 2: Override bằng environment variable
DEBUG=true ruby example.rb

# Cách 3: Dùng option --debug (chỉ với get_user_story.rb)
ruby get_user_story.rb -i 106864 --debug
```

## Sử dụng

### 1. Script đơn giản (example.rb)

Chạy các ví dụ cơ bản:

```bash
# Cách 1: Sử dụng file .env (Khuyến nghị - ĐƠN GIẢN NHẤT!)
# Sau khi đã cấu hình file .env, chỉ cần:
ruby example.rb

# Cách 2: Inline environment variables (override .env)
HTTP_USERNAME=user HTTP_PASSWORD=pass REDMINE_API_KEY=key ruby example.rb
```

### 2. Script nâng cao (get_user_story.rb)

Script này hỗ trợ nhiều tùy chọn để lấy thông tin issues:

#### Lấy thông tin một issue cụ thể:

```bash
# Cách 1: Sử dụng .env (ĐƠN GIẢN!)
ruby get_user_story.rb -i 106864

# Cách 2: Override với env variables
HTTP_USERNAME=user HTTP_PASSWORD=pass REDMINE_API_KEY=key ruby get_user_story.rb -i 106864
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

# Xuất danh sách issues dạng JSON và lưu vào file
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
├── dotenv.rb              # Auto-loader cho .env file
├── example.rb             # Script ví dụ đơn giản
├── get_user_story.rb      # Script nâng cao với nhiều options
├── .env.example           # Template cho file cấu hình
├── .env                   # File cấu hình (tự tạo, đã có trong .gitignore)
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
www-authenticate: Basic realm="closed site"
```

**Đây là lỗi HTTP Basic Auth từ nginx!** Website được bảo vệ bởi 2 lớp authentication.

**Nguyên nhân và giải pháp:**

1. **CHƯA CÓ HTTP_USERNAME và HTTP_PASSWORD** (Nguyên nhân phổ biến nhất!)
   ```bash
   # ĐÚNG - Cần cả HTTP Basic Auth VÀ Redmine API Key
   HTTP_USERNAME=httpuser HTTP_PASSWORD=httppass REDMINE_API_KEY=key ruby example.rb

   # SAI - Thiếu HTTP Basic Auth
   REDMINE_API_KEY=key ruby example.rb
   ```

2. **HTTP Basic Auth credentials sai**
   - Kiểm tra lại HTTP_USERNAME và HTTP_PASSWORD
   - Đây là credentials cho nginx, không phải Redmine user
   - Liên hệ admin để lấy credentials đúng

3. **Redmine API Key sai hoặc hết hạn**
   - Sau khi đã qua được HTTP Basic Auth, vẫn cần Redmine authentication
   - Vào Redmine > My account > API access key
   - Click "Reset" để tạo key mới

4. **Kiểm tra với Debug Mode**
   ```bash
   DEBUG=true HTTP_USERNAME=user HTTP_PASSWORD=pass REDMINE_API_KEY=key ruby example.rb
   ```

   Debug sẽ hiển thị:
   - Có đang dùng HTTP Basic Auth không
   - Headers được gửi đi
   - Response từ server

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