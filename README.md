# Discord DPI Launcher

<p align="center">
  <img src="Resources/AppIcon.png" alt="Discord DPI Launcher logo" width="180">
</p>

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

İlk ses kanalı bağlantısında macOS mikrofon izni isteyebilir. Sesli görüşme için bu izni verin.

## Derleme

Terminal'de proje klasörüne girip:

```bash
./build-app.sh
```

Uygulama `dist/Discord DPI Launcher.app` altında oluşur.

Uygulamayı kapatmak, uygulamanın başlattığı SpoofDPI sürecini de durdurur. Başka bir SpoofDPI zaten 8080 portunda çalışıyorsa uygulama onu kullanır ve kapatmaz.
