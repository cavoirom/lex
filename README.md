# Lex

Bộ gõ Tiếng Việt dùng kiểu gõ Telex được tùy chỉnh phù hợp với cách dùng của tác giả.

Mục đích của chương trình là để hiểu rõ hơn về tính khả thi của cấu trúc chương trình hỗ trợ đa nền
tảng trong đó phần thuật toán chính sẽ được viết trong 1 thư viện dùng chung bằng Zig và chương
trình chính được viết bởi ngôn ngữ phù hợp với từng nền tảng. Ý tưởng này bắt nguồn từ cách lập
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
  - [x] Dấu của nguyên âm, phụ âm `d` phải bỏ liền sau ký tự đó.
  - [x] Dấu của từ có thể bỏ ở cuối từ.
- [x] Bật / tắt nhập Tiếng Việt: `Ctrl + Opt + Space`.
- [x] Chỉ hiện biểu tượng trên thanh Menu của macOS.
- [x] Khởi động khi đăng nhập.
- [ ] Phím tắt để xóa trạng thái gõ Tiếng Việt: `Ctrl (left)`.
- [ ] Khóa bàn phím.

Lưu ý: chương trình được thiết lập mặc định theo những chức năng trên và không thể tùy chỉnh. Người
dùng có thể tắt chức năng _Khởi động khi đăng nhập_ trong menu (macOS 26): System Settings \>
General \> Login Items & Extensions \> Open at Login.

## Hướng dẫn cấp quyền _Accessibility_ cho Lex

Vì bộ gõ Tiếng Việt cần truy cập vào tín hiệu gõ phím của người dùng để bỏ dấu, Lex cần được cung
cấp quyền _Accessibility_ trước khi khởi động. Truy cập vào menu: System Settings \> Privacy &
Security \> Accessibility: thêm _Lex.app_ vào danh sách được cấp quyền.

Khởi động Lex sau khi đã cấp quyền.

## Lộ trình

- [x] 0.1.x
  - [x] Chỉ hiện biểu tượng trên thanh Menu của macOS.
  - [x] Nhập Tiếng Việt kiểu Telex với một số tùy chỉnh:
    - [x] Bỏ dấu kiểu cũ: _òa_, _úy_. Ví dụ: _hòa_, _thúy_.
    - [x] Không bỏ dấu nếu từ bắt đầu bằng phụ âm không phải Tiếng Việt: _f_, _j_, _w_, _z_.
    - [x] Dấu của nguyên âm, phụ âm `đ` phải bỏ liền sau ký tự đó.
    - [x] Dấu của từ có thể bỏ ở cuối từ.
  - [x] Phím tắt bật / tắt nhập Tiếng Việt: `Ctrl + Opt + Space`.
  - [x] Khởi động khi đăng nhập.
- [ ] 0.2.x
  - [ ] Phím tắt để xóa trạng thái gõ Tiếng Việt: `Ctrl (left)`.
  - [ ] Khóa bàn phím.
- [ ] 0.3.x
  - [ ] Hoàn thiện cơ chế kiểm thử.
- [ ] 1.0.x - tất cả chức năng đã hoàn thành.

## Tự biên dịch chương trình

Yêu cầu:

- macOS 26 hoặc mới hơn.
- Zig 0.15.2.
- Xcode 26 hoặc mới hơn.

Biên dịch liblex.a:

```
zig build-obj -target aarch64-macos.26.0 -O ReleaseSafe src/lex.zig -femit-bin=liblex.o \
    && xcrun libtool -static -o liblex.a liblex.o
```

Bên dịch Lex:

```
mkdir -p macos/Lex.app/Contents/MacOS/
swiftc -parse-as-library -import-objc-header src/lex.h ./liblex.a macos/Lex.swift -o macos/Lex.app/Contents/MacOS/Lex
```

Ký chữ ký điện tử để macOS đồng ý cấp quyền _Accessibility_:

```
codesign -f -s - macos/Lex.app
```

## Tình hình phát triển

Đã hoàn thành bản _0.1.0_, do tác giả chưa là thành viên của Apple Developer Program nên người dùng
cần tự biên dịch chương trình từ mã nguồn hoặc
[tải bản unsigned](https://github.com/cavoirom/lex/releases) về rồi tự sign bằng lệnh:
`codesign -f -s - Lex.app`.
