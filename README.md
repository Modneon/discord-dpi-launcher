# Discord DPI Launcher

macOS için küçük bir SwiftUI başlatıcısıdır.

Uygulama açıldığında SpoofDPI'yi şu yapılandırmayla başlatır:

- HTTP proxy: `127.0.0.1:8080`
- DNS over HTTPS ve yalnızca IPv4
- HTTPS parçalama: `chunk`, boyut `1`, disorder açık
- macOS sistem proxy yapılandırması açık

**Discord'u Aç** düğmesi Discord'u tamamen kapatıp aşağıdaki ayarlarla yeniden başlatır:

- `HTTP_PROXY`, `HTTPS_PROXY` ve `ALL_PROXY` → `http://127.0.0.1:8080`
- `--proxy-server=http://127.0.0.1:8080`
- `--disable-quic`

## Gereksinimler

- macOS 13 veya üzeri
- `/Applications/Discord.app`
- Homebrew ile kurulmuş SpoofDPI (`/opt/homebrew/bin/spoofdpi` veya `/usr/local/bin/spoofdpi`)

## Derleme

Terminal'de proje klasörüne girip:

```bash
./build-app.sh
```

Uygulama `dist/Discord DPI Launcher.app` altında oluşur.

Uygulamayı kapatmak, uygulamanın başlattığı SpoofDPI sürecini de durdurur. Başka bir SpoofDPI zaten 8080 portunda çalışıyorsa uygulama onu kullanır ve kapatmaz.
