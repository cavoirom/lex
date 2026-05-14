# Lex

Bộ gõ Tiếng Việt dùng kiểu gõ Telex được tùy chỉnh phù hợp với cách dùng của tác giả.

Mục đích của chương trình là để hiểu rõ hơn về tính khả thi của cấu trúc chương trình hỗ trợ đa nền
tảng trong đó phần thuật toán chính sẽ được viết trong 1 thư viện dùng chung bằng Zig và chương
trình chính được viết bởi ngôn ngư phù hợp với từng nền tảng. Ý tưởng này bắt nguồn từ cách lập
trình của
[Dropbox](https://oleb.net/blog/2014/05/how-dropbox-uses-cplusplus-cross-platform-development/) và
[Ghostty](https://mitchellh.com/writing/ghostty-and-useful-zig-patterns).

Lưu ý: Dropbox đã chuyển sang cách lập trình khác vì khó khăn trong lúc tích hợp thư viện, tuyển
người, đào tạo... Những khó khăn này không phải là vấn đề lớn khi tác giả là người duy nhất chịu
trách nhiệm cho toàn bộ chương trình.

## Chạy được trên hệ điều hành

- macOS 26.0 trở về sau.

## Chức năng

- [x] Nhập Tiếng Việt kiểu Telex với một số tùy chỉnh:
  - [x] Bỏ dấu kiểu cũ: _òa_, _úy_. Ví dụ: _hòa_, _thúy_.
  - [x] Không bỏ dấu nếu từ bắt đầu bằng phụ âm không phải Tiếng Việt: _f_, _j_, _w_, _z_.
- [ ] Phím tắt bật / tắt nhập Tiếng Việt: `Ctrl + Opt + Space`.
- [ ] Phím tắt để xóa trạng thái gõ Tiếng Việt: `Ctrl (left)`.
- [ ] Chỉ hiện biểu tượng trên thanh Menu của macOS.
- [ ] Khởi động khi đăng nhập.

## Lộ trình

- [ ] 0.1.x
  - [ ] Chỉ hiện biểu tượng trên thanh Menu của macOS.
  - [x] Nhập Tiếng Việt kiểu Telex với một số tùy chỉnh:
    - [x] Bỏ dấu kiểu cũ: _òa_, _úy_. Ví dụ: _hòa_, _thúy_.
    - [x] Không bỏ dấu nếu từ bắt đầu bằng phụ âm không phải Tiếng Việt: _f_, _j_, _w_, _z_.
  - [ ] Phím tắt bật / tắt nhập Tiếng Việt: `Ctrl + Opt + Space`.
- [ ] 0.2.x
  - [ ] Phím tắt để xóa trạng thái gõ Tiếng Việt: `Ctrl (left)`.
- [ ] 0.3.x
  - [ ] Khởi động khi đăng nhập.
- [ ] 0.4.x
  - [ ] Hoàn thiện cơ chế kiểm thử.
- [ ] 1.0.x - tất cả chức năng đã hoàn thành.

## Tình hình phát triển hiện tại

[Bản mẫu](./playground/prototype-app/) có thể chạy được và gõ được Tiếng Việt. Đang phát triển bản
chính thức. Gần như toàn bộ code Zig, Swift ở bản mẫu là do coding agent viết, code của bản chính
thức sẽ được tác giả tự viết (phần lớn) và dùng coding agent để hỗ trợ những chỗ trùng lặp.
