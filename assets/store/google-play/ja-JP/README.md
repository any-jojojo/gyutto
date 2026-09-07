# ぎゅっと Google Play 掲載素材

- icon-512.png：正式掲載用アイコン、512×512 PNG。既存ロゴをもとに文字を取り除き、マークを拡大。
- icon-master.png：画像生成の原寸マスター。
- feature-1024x500.png：1024×500。既存 images/gyutto_Image1024x500.png を採用。
- phone/：1080×1920 の縦画面3枚。実際の Flutter ウィジェットを架空データで描画。端末撮影ではなく、画面書き出し。OSステータスバーは含まない。
- listing.md：アプリ名、短い説明、詳しい説明、画面紹介文案。

スクリーンショット順：家族チャット → 家族ホーム → 開始画面。ホームと開始画面はスクロール先の内容を含まない初期表示です。
スクリーンショット再生成：app/ で flutter test --no-pub test/store_capture_test.dart。Windows のメイリオを撮影用に読み込みます。実サービスには接続しません。
アプリ本体のアイコン差し替え、ストアへのアップロードは含みません。

仕様参照（2026-09-07）：https://support.google.com/googleplay/android-developer/answer/9866151?hl=ja

## アイコン制作記録
内蔵 image_gen を使用。最終 PNG は512×512へリサイズ。参照画像：images/gyutto_Image512x512.png。

最終プロンプト：
Use case: logo-brand. Edit the supplied existing official Gyutto logo into a production app icon. Keep exactly the recognizable circular embracing large and small hands line art, orange coral to periwinkle blue gradient, warm off-white background. Remove ALL lettering and tagline. Enlarge the circular hands mark to occupy 78 percent of the square width, perfectly centered vertically and horizontally. Crisp clean smooth lines matching the reference, not a new symbol. Full bleed square background, no outer rounded corners, no shadows, no border, no text. Output 512x512 PNG.
