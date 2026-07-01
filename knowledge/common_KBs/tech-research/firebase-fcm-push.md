---
date: 2026-06-26
keywords: Firebase, FCM, Push Notification, 推播, Realtime Database, 聊天室, Android, Spring Boot, Google Chat, Webhook
---

# Firebase 推播通知與即時應用

## 問題背景

在行動應用中需要實作推播通知（FCM）及即時聊天室（Firebase Realtime Database）功能，同時需要 Server 端（Spring Boot）與 Client 端（Android）的整合方式。

---

## FCM 推播通知架構

```
Server（Spring Boot）
  ↓ 透過 Firebase Admin SDK 送出
Firebase Cloud Messaging (FCM)
  ↓
Android / iOS / Web App（接收推播）
```

---

## Server 端推播（Spring Boot）

### Step 1：新增 Firebase Admin SDK 相依

```xml
<dependency>
    <groupId>com.google.firebase</groupId>
    <artifactId>firebase-admin</artifactId>
    <version>7.0.0</version>
</dependency>
```

### Step 2：取得 Service Account Private Key

1. 進入 Firebase Console → 專案設定 → 服務帳戶 (Service Accounts)
2. 點擊 **Generate new private key**
3. 下載 `<firebase-project>-firebase-adminsdk-<hash>.json`
4. 將檔案重命名為 `firebase-service-account.json`
5. 存放於 `src/main/resources/` 目錄下

### Step 3：設定 Spring Bean

```java
@Bean
FirebaseMessaging firebaseMessaging() throws IOException {
    GoogleCredentials googleCredentials = GoogleCredentials
            .fromStream(new ClassPathResource("firebase-service-account.json")
                .getInputStream());
    FirebaseOptions firebaseOptions = FirebaseOptions
            .builder()
            .setCredentials(googleCredentials)
            .build();
    FirebaseApp app = FirebaseApp.initializeApp(firebaseOptions);
    return FirebaseMessaging.getInstance(app);
}
```

### Step 4：發送推播訊息

```java
// 建立 Message
Message message = Message.builder()
    .setToken(deviceToken)    // FCM token from device
    .setNotification(Notification.builder()
        .setTitle("標題")
        .setBody("內容")
        .build())
    .putData("key", "value")  // 自定義 data payload
    .build();

// 發送（回傳 message ID）
String response = FirebaseMessaging.getInstance().send(message);
```

### RESTful API 直接推播（測試用）

```http
POST https://fcm.googleapis.com/fcm/send
Content-Type: application/json
Authorization: key=<SERVER_KEY>

{
  "to": "dinKZPh3R5yTNEGWcq8....",
  "priority": "high",
  "data": {
    "body": "推播帶給 APP 的資訊"
  },
  "notification": {
    "title": "推播跳出的標題",
    "body": "推播跳出的訊息內容",
    "click_action": "OPEN_ACTIVITY_1"
  }
}
```

---

## Client 端推播（Android）

### 步驟一：Firebase Console 設定

1. 到 [Firebase Console](https://console.firebase.google.com) 建立或選擇 Firebase project
2. 左欄選擇 Cloud Messaging
3. 點選 Android 圖示建立 app
4. 填入 Android app 的 package name（如 `com.example.myapp`）
5. 點擊 Register app
6. 下載 `google-services.json`

### 步驟二：project-level `build.gradle`

```groovy
buildscript {
    repositories { google(); jcenter() }
    dependencies {
        classpath 'com.android.tools.build:gradle:4.1.3'
        classpath 'org.jetbrains.kotlin:kotlin-gradle-plugin:1.3.72'
        // 新增
        classpath 'com.google.gms:google-services:4.3.5'
    }
}
```

### 步驟三：app-level `build.gradle`

```groovy
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    // 新增
    id 'com.google.gms.google-services'
}

dependencies {
    // Firebase BOM（統一管理版本）
    implementation platform('com.google.firebase:firebase-bom:28.0.0')
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'com.google.firebase:firebase-analytics'
}
```

### 步驟四：將 `google-services.json` 加入專案

- 將下載的 `google-services.json` 放入 `app/` 資料夾

### 步驟五：實作 FCM Service 接收推播

```kotlin
class MyFirebaseMessagingService : FirebaseMessagingService() {

    // Token 更新時呼叫（需將新 token 傳送至 Server）
    override fun onNewToken(token: String) {
        sendTokenToServer(token)
    }

    // 收到推播時呼叫
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // 處理 notification payload（前台顯示）
        remoteMessage.notification?.let { notification ->
            showNotification(notification.title, notification.body)
        }
        // 處理 data payload（後台自定義邏輯）
        remoteMessage.data.let { data ->
            // 自定義處理邏輯
        }
    }
}
```

---

## Firebase Realtime Database（即時聊天室）

### 為什麼選擇 Firebase Realtime Database？

| 優勢 | 說明 |
|------|------|
| **即時同步** | 自動即時同步所有連接裝置上的資料，非常適合聊天應用 |
| **可擴展性** | 可處理大量並發使用者和訊息 |
| **安全性** | 提供強大的安全規則和身份驗證機制 |
| **離線支援** | 提供離線功能，使用者未連網也可繼續聊天 |

Firebase Realtime Database 是 **NoSQL 資料庫**，資料以 JSON 樹狀結構儲存。

### 聊天室資料結構設計

```json
{
  "chats": {
    "chatroom_id": {
      "messages": {
        "message_id": {
          "text": "訊息內容",
          "sender": "user_id",
          "timestamp": 1673000000000
        }
      },
      "members": {
        "user_id": true
      }
    }
  }
}
```

### Android 監聽即時資料

```kotlin
val database = Firebase.database
val messagesRef = database.getReference("chats/$chatroomId/messages")

messagesRef.addValueEventListener(object : ValueEventListener {
    override fun onDataChange(snapshot: DataSnapshot) {
        // 訊息更新，重新載入資料
        val messages = snapshot.children.mapNotNull { it.getValue(Message::class.java) }
        updateUI(messages)
    }
    override fun onCancelled(error: DatabaseError) {
        Log.e("Firebase", "Error: ${error.message}")
    }
})
```

---

## Google Chat Webhook（系統通知）

Webhook 可實現從外部應用程式到 Google Chat 的非同步消息傳送，適合 CI/CD 通知、系統告警。

### 建立 Webhook

1. 進入 Google Chat Space
2. 點擊 Space 設定 → 應用程式與整合
3. 新增 Webhook，複製 Webhook URL

### Spring Boot 發送訊息

```java
@Service
public class GoogleChatService {

    private final RestTemplate restTemplate;
    private final String webhookUrl;

    // 發送純文字
    public void sendMessage(String text) {
        Map<String, String> body = Map.of("text", text);
        restTemplate.postForEntity(webhookUrl, body, String.class);
    }
}
```

### 訊息格式

**純文字**：
```json
{ "text": "普通文字訊息" }
```

**Card 格式**（含標題、內容）：
```json
{
  "cards": [{
    "header": {
      "title": "訊息標題",
      "subtitle": "副標題"
    },
    "sections": [{
      "widgets": [{
        "textParagraph": {
          "text": "內容文字"
        }
      }]
    }]
  }]
}
```

## 參考

- [Firebase Admin SDK 文件](https://firebase.google.com/docs/admin/setup)
- [FCM 推播文件](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Realtime Database 文件](https://firebase.google.com/docs/database)
- [Google Chat Webhook](https://developers.google.com/chat/how-tos/webhooks)
