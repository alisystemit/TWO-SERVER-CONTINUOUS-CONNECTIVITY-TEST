# اسکریپت بررسی ارتباط بین دو سرور

یک اسکریپت Bash جامع برای بررسی پایداری ارتباط بین دو سرور در لایه‌های **gRPC** و **REST**.

## ویژگی‌ها

- ✅ نصب خودکار پیش‌نیازها (curl, netcat, ping, jq)
- ✅ دریافت IP سرورها از کاربر (فقط یک‌بار در ابتدا)
- ✅ تنظیمات قابل تغییر: پورت gRPC، پورت REST، فاصله بین تست‌ها، timeout
- ✅ آزمایش خودکار پروتکل‌های gRPC و REST
- ✅ اندازه‌گیری تأخیر (latency) برای هر تست
- ✅ آمار موفقیت/شکست در هر ۱۰ تست
- ✅ اعلان هنگام قطع/وصل ارتباط
- ✅ خروجی رنگی و خوانا
- ✅ ثبت لاگ در فایل متنی و JSON (اختیاری)
- ✅ اجرای مداوم تا زمان توقف دستی (Ctrl+C)

## پیش‌نیازها

- سیستم عامل Linux (Ubuntu/Debian, CentOS, Alpine) یا macOS
- دسترسی sudo برای نصب بسته‌ها
- bash نسخه ۴ به بالا

## نصب و اجرا

### نصب سریع با یک کلیک

```bash
curl -sL https://raw.githubusercontent.com/alisystemit/TWO-SERVER-CONTINUOUS-CONNECTIVITY-TEST/main/connectivity-test.sh | sudo bash
```

> **نکته:** برای اجرای مستقیم با curl، از لینک raw استفاده کنید تا اسکریپت اجرا شود. آدرس صفحه پروژه: `https://github.com/alisystemit/TWO-SERVER-CONTINUOUS-CONNECTIVITY-TEST/blob/main/connectivity-test.sh`

### روش دستی

```bash
# ۱. دانلود اسکریپت
curl -O https://raw.githubusercontent.com/alisystemit/TWO-SERVER-CONTINUOUS-CONNECTIVITY-TEST/main/connectivity-test.sh

# ۲. دادن دسترسی اجرایی
chmod +x connectivity-test.sh

# ۳. اجرای اسکریپت
./connectivity-test.sh
```

## نحوه کار

1. **مرحله نصب**: اسکریپت پیش‌نیازها را خودکار نصب می‌کند.
2. **دریافت IP**: IP سرور اول و دوم را از شما می‌گیرد.
3. **تنظیمات**: پورت‌ها و پارامترهای تست قابل تغییرند (Enter=مقادیر پیش‌فرض).
4. **اجرای مداوم**: هر چند ثانیه یک‌بار وضعیت اتصال gRPC و REST را چک می‌کند.
5. **خروج**: با فشردن `Ctrl+C` متوقف می‌شود و آمار کلی نمایش داده می‌شود.

## پارامترهای قابل تنظیم

| پارامتر | پیش‌فرض | توضیح |
|---------|---------|-------|
| پورت gRPC | `50051` | پورت سرویس gRPC |
| پورت REST | `80` | پورت سرویس REST |
| فاصله بین تست‌ها | `3` ثانیه | Sleep بین هر آزمون |
| Timeout | `3` ثانیه | حداکثر زمان انتظار برای هر تست |
| لاگ JSON | غیرفعال | در صورت y فعال می‌شود |

## نمونه خروجی

```
--- Test #1 | 2026-10-07 15:30:00 ---
  ✅ ICMP (Server1 → Server2) [info only]: connected (12ms)
  ✅ TCP REST port 80 (Server1 → Server2): connected (8ms)
  ✅ TCP gRPC port 50051 (Server1 → Server2): connected (9ms)
  ✅ REST (port 80): connected (45ms)
  ✅ gRPC (port 50051): connected (7ms)
```

### اعلان وضعیت

```
🔔 Connection lost!
🔔 Connection restored!
```

### آمار دوره‌ای

```
--- Statistics after 10 tests ---
ICMP: 10/10  |  TCP REST: 10/10  |  TCP gRPC: 10/10
REST: 9/10  |  gRPC: 10/10
```

## فایل‌های لاگ

- `connectivity-test-YYYYMMDD-HHMMSS.log` : لاگ متنی همه رویدادها
- `connectivity-test-YYYYMMDD-HHMMSS.json` : لاگ JSON (اختیاری)

## نکات مهم

- این اسکریپت باید روی **هر دو سرور** اجرا شود.
- در هر اجرا، IP سرور مقابل را وارد کنید.
- اگر پورت‌های شما متفاوت است، در مرحله تنظیمات آن را وارد کنید.

## مشارکت

اگر پیشنهاد یا باگ گزارش دارید، خوشحال می‌شوم آن را بهبود دهم.

---

**ساخته شده با ❤️ برای تست زیرساخت شبکه**
