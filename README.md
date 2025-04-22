# Kodain

<!-- Logo Yer Tutucusu -->
<p align="center">
  <img src="kodain/Assets.xcassets/AppIcon.appiconset/1024.png" alt="Kodain Logo" width="200"/>
  <!-- TODO: Yukarıdaki `src` yolunu logo dosyanızın yoluyla değiştirin (örn: Resources/logo.png) -->
</p>

<p align="center">
  <em>AI-Powered Tools for Smarter Development</em>
</p>

---

<!-- İsteğe Bağlı Rozetler: Projenize uygun olanları ekleyebilirsiniz -->
<!-- [![Build Status](...)](...) [![License](...)](...) -->

Kodain, Google'ın Üretken Yapay Zekası tarafından desteklenen akıllı bir sohbet arayüzü sağlayarak geliştirme iş akışını iyileştirmek için tasarlanmış yerel bir macOS uygulamasıdır. Kodlama yardımı, beyin fırtınası ve daha fazlası için yapay zeka modelleriyle etkileşim kurun ve konuşmalarınızı sezgisel bir arayüzde kolayca yönetin ve organize edin.

## ✨ Temel Özellikler

*   **🧠 Yapay Zeka Sohbet Arayüzü:** Kodlama yardımı, fikir üretme ve daha fazlası için Google Generative AI modelleriyle etkileşim kurun.
*   **🖼️ Ekran Görüntüsü Sohbeti:** Ekranınızın bir bölümünün görüntüsünü yakalayın ve doğrudan bu görüntü hakkında AI ile sohbet edin (görsel kod analizi, UI/UX geri bildirimi vb.).
*   **🗂️ Oturum Yönetimi:** Konuşmaları ayrı sohbet oturumlarında düzenleyin.
*   **📂 Klasör Organizasyonu:** İlgili oturumları iç içe yerleştirme desteğiyle klasörler halinde gruplayın.
*   **🎨 Renk Kodlaması:** Oturumları ve klasörleri daha iyi görsel organizasyon için özel renklerle etiketleyin.
*   **⭐ Favoriler:** Önemli oturumları hızlı erişim için favori olarak işaretleyin.
*   **⌨️ Hızlı Erişim:** Global klavye kısayolu (varsayılan: çift **Option (⌥)**) ile uygulamayı anında gösterin/gizleyin.
*   **🧭 Zengin Kenar Çubuğu:** Oturumlara ve klasörlere dinamik ve etkileşimli bir kenar çubuğuyla kolayca göz atın.
*   **🖱️ Bağlam Menüleri ve Kaydırma Eylemleri:** Yeniden adlandırma, silme, taşıma, favorilere ekleme ve renklendirme gibi eylemleri bağlam menüleri ve kaydırma hareketleriyle (trackpad) hızla gerçekleştirin.
*   **💾 Kalıcılık:** Oturumlar ve klasörler yerel olarak `UserDefaults` kullanılarak kaydedilir.
*   **💻 Modern macOS Arayüzü:** SwiftUI ile oluşturulmuş, macOS İnsan Arayüzü Yönergelerine uygun modern bir arayüz.

## 🚀 Kullanılan Teknolojiler

*   **Swift:** Ana programlama dili.
*   **SwiftUI:** macOS için modern kullanıcı arayüzü çatısı.
*   **Google Generative AI SDK for Swift:** Google'ın yapay zeka modelleriyle arayüz oluşturmak için (metin ve görsel anlama).
*   **Combine:** Reaktif programlama için (`ObservableObject`).
*   **UserDefaults:** Yerel veri kalıcılığı için.
*   **AppKit:** Global klavye kısayolu izleme ve Erişilebilirlik API'ları için.
*   **ScreenCaptureKit / AVFoundation:** Ekran görüntüsü almak için.

## 🛠️ Başlarken

1.  **Depoyu Klonlayın:**
    ```bash
    git clone https://github.com/kullanici-adiniz/kodain.git # Depo URL'niz ile değiştirin
    cd kodain
    ```
2.  **Xcode'da Açın:** `kodain.xcodeproj` dosyasını açın.
3.  **API Anahtarını Yapılandırın:** Google Generative AI API anahtarınızı sağlamanız gerekecektir. Muhtemelen `GenerativeModel`'in başlatıldığı ilgili kod bölümlerini (`ChatViewModel.swift` veya benzeri olabilir) kontrol edin veya bir yapılandırma adımı ekleyin. (Uygulamanın çalışması için bu adım kritik öneme sahiptir.)
4.  **Derleyin ve Çalıştırın:** Bir macOS hedefi seçin ve uygulamayı çalıştırın (Cmd+R).
5.  **Gerekli İzinler:**
    *   **Erişilebilirlik:** Uygulama ilk çalıştığında, global klavye kısayolunun (çift Option) çalışabilmesi için Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik bölümünden izin vermeniz istenebilir.
    *   **Ekran Kaydı:** Ekran görüntüsü üzerinden sohbet özelliğini kullanmak için, uygulama ilk kez bu özelliği tetiklediğinizde Sistem Ayarları > Gizlilik ve Güvenlik > Ekran Kaydı bölümünden izin vermeniz istenecektir.

## ⚙️ Kullanım

1.  **Uygulamayı Göster/Gizle:** Herhangi bir uygulamadayken **Option (⌥)** tuşuna hızlıca iki kez basarak Kodain penceresini anında açın veya gizleyin.
2.  **Sohbet Başlatma:** Yeni sohbet oturumları oluşturmak için kenar çubuğundaki '+' düğmesini veya Cmd+N kısayolunu kullanın.
3.  **Ekran Görüntüsü ile Sohbet:** Sohbet giriş alanındaki ilgili butona tıklayarak ekranın bir bölümünü seçin. Seçilen görüntü sohbete eklendikten sonra, bu görüntü hakkında sorular sorabilirsiniz.
4.  **Sohbet ve Yönetim:** Oturumlarınızı kenar çubuğu düğmeleri, sürükle-bırak veya öğeler üzerindeki bağlam menüleri/kaydırma eylemleri aracılığıyla klasörler kullanarak düzenleyin. Oturumları veya klasörleri renklendirmek ve favorilere eklemek için bağlam menülerini veya kaydırma eylemlerini kullanın.

## 🧪 Demo Veri Özelliği

Uygulama, başlangıçta kullanıcılara özellikleri hızlıca tanıtabilmek ve arayüzü deneyimleyebilmelerini sağlamak için isteğe bağlı olarak yüklenebilen bir demo veri seti sunar. Bu demo veriler, örnek sohbet oturumlarını, klasör yapılarını ve renk kodlamalarını içerir. Demo veriler, uygulamanın ilk açılışında veya Ayarlar bölümünden yüklenebilir.

## 💾 Data Yönetimi

*   **Veri Depolama ve Boyut:** Tüm kullanıcı verileri (sohbet oturumları, klasörler, ayarlar vb.) basitlik ve hız için yerel olarak `UserDefaults` kullanılarak saklanır. `UserDefaults` genellikle metin tabanlı veriler için tasarlandığından, depolanan veri miktarı genellikle küçüktür ve uygulamanın sistemdeki tercih dosyasında yer alır. Büyük medya dosyaları veya çok büyük sohbet geçmişleri saklanmaz. Bu verilerin boyutu Ayarlar > Veri sekmesinden görüntülenebilir. 
*   **Veri Sıfırlama:** Kullanıcıların tüm sohbet geçmişini, klasör yapılarını ve kişisel ayarlarını kolayca silerek uygulamayı ilk kurulum durumuna döndürebilmeleri için bir "Tüm Verileri Sil" işlevi eklenmiştir. Bu işlem, `UserDefaults` içindeki uygulamaya ait tüm kayıtları temizleyecektir.
*   **Durum Yönetimi:** Uygulama, SwiftUI'ın yerleşik durum yönetimi araçlarını (`@State`, `@StateObject`, `@EnvironmentObject`) ve MVVM (Model-View-ViewModel) mimarisini kullanır. `Combine` framework'ü, özellikle `ObservableObject` protokolü aracılığıyla, veri akışını ve UI güncellemelerini reaktif bir şekilde yönetmek için kullanılır. Bu, kullanıcı arayüzünün veri modelindeki değişikliklere otomatik olarak tepki vermesini sağlar.

## ❤️ Katkıda Bulunma

Katkılarınızı bekliyoruz! Lütfen bir "issue" açın veya bir "pull request" gönderin.

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır. 