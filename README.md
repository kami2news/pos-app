# pos_app

イベント向けPOSアプリ（Flutter Web）

## セットアップ手順

```bash
# 1. このフォルダをFlutterプロジェクトとして初期化（web/フォルダ等を補完）
flutter create . --platforms web

# 2. パッケージ取得
flutter pub get

# 3. コード生成（freezed / json_serializable）
dart run build_runner build --delete-conflicting-outputs

# 4. 起動
flutter run -d chrome
```

## フォルダ構成

```
lib/
├── main.dart               # エントリポイント
├── router/
│   └── router.dart         # go_router（画面遷移・リダイレクト）
├── core/                   # 共通処理（dio設定等）
└── features/
    ├── auth/               # ログイン認証
    ├── opening/            # 開設作業
    ├── order/              # 注文入力・注文一覧
    ├── closing/            # 締め作業
    └── products/           # 商品管理
```

## 画面フロー

ログイン → BusinessDay.status で自動振り分け
- status = 'open'  → 注文入力画面
- status = null    → 開設作業画面
- status = 'closed'→ 開設作業画面
