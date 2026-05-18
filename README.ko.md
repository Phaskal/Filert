# Filert

파일과 폴더의 변경을 감지해 네이티브 알림을 보내는 macOS 메뉴바 앱입니다.

Filert는 메뉴바에 조용히 상주하며 감시 목록에 추가한 파일이나 폴더를 모니터링합니다. 변경이 감지되면 변경 시각이 담긴 알림을 보내고, Finder에서 바로 열 수 있는 버튼을 제공합니다. iCloud Drive 파일을 특히 잘 처리하도록 설계되어 있으며, Mac이 잠들어 있는 동안 다른 기기에서 발생한 변경도 깨어나는 즉시 감지합니다.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgray) ![Swift](https://img.shields.io/badge/swift-5.9-orange)

---

## 무엇을 하나요

대부분의 파일 동기화 도구는 변경이 *있었다*는 사실만 알려줍니다. Filert는 *언제* 변경됐는지를 알려주고 바로 행동할 수 있게 합니다. 폴더나 파일을 추가하면 그 시점부터 수정, 생성, 이름 변경이 발생할 때마다 알림이 옵니다. 알림을 클릭하거나 파일 열기 버튼을 누르면 Finder에서 해당 파일로 바로 이동합니다.

iCloud Drive는 복잡한 문제를 추가합니다. 노트북이 닫혀 있는 동안 다른 기기에서 변경이 일어날 수 있고, Mac이 깨어난 후 일반적인 파일 시스템 이벤트는 너무 늦게 발생하거나 아직 다운로드되지 않은 파일에는 아예 발생하지 않습니다. Filert는 수면 전 모든 감시 항목의 마지막 수정 날짜를 기록해 두고, 깨어난 후 현재 메타데이터와 비교합니다. 로컬 파일 시스템과 NSMetadataQuery를 함께 사용해 아직 클라우드에만 있는 파일도 커버합니다.

## 기능

- **메뉴바 전용** — Dock 아이콘 없음, 실행 시 창 없음; 방해 없이 상태 아이콘으로만 동작
- **실시간 감시** — 2초 이벤트 병합 창을 가진 FSEvents 스트림으로 알림 폭주 방지
- **iCloud 지원** — NSMetadataQuery가 로컬에 다운로드되기 전에도 iCloud Drive 파일 변경을 감지
- **수면 후 복구** — 깨어날 때 저장된 수정 날짜와 현재 메타데이터를 비교해 수면 중 변경 알림
- **액션 알림** — 알림 클릭 또는 파일 열기 / 닫기 버튼으로 Finder에서 열기 또는 닫기
- **미읽음 표시** — 미확인 변경이 있으면 메뉴바 아이콘이 채워진 형태로 전환, 확인하면 원래대로
- **영속 감시 목록** — 감시 경로와 마지막 확인 날짜가 UserDefaults에 저장되어 재시작 후에도 유지

## 시작하기

1. 앱 실행 — 메뉴바에 `doc.badge.clock` 아이콘이 나타납니다
2. 아이콘 클릭 후 **설정...** 선택 (`⌘,`)
3. **+** 클릭 후 감시할 파일 또는 폴더를 하나 이상 선택
4. 알림 권한 허용: **시스템 설정 → 알림 → Filert**
5. 감시 항목에 변경이 생기면 알림이 옵니다

알림을 클릭하거나 **파일 열기** 버튼을 누르면 Finder에서 변경된 파일의 위치가 표시됩니다. 폴더의 경우 해당 폴더가 바로 열립니다. **닫기** 버튼은 아무 것도 열지 않고 알림만 닫습니다.

## 요구 사항

- macOS 13.0 Ventura 이상
- Xcode 15 이상

## 빌드

```bash
git clone https://github.com/Phaskal/Filert.git
cd Filert
open Filert.xcodeproj
```

Xcode에서 **⌘R**로 빌드 및 실행합니다.

## 프로젝트 구조

```
Filert/
├── FilertApp.swift              # @main — MenuBarExtra + Settings scene
├── AppDelegate.swift            # 앱 생명주기, 서비스 시작
├── Models/
│   ├── WatchedPath.swift        # Codable 감시 경로 모델
│   └── ChangeRecord.swift       # 포맷된 타임스탬프를 포함한 변경 이벤트 모델
├── Services/
│   ├── FileWatcherService.swift  # FSEvents C API 래퍼
│   ├── ICloudMonitor.swift       # iCloud Drive 파일용 NSMetadataQuery
│   ├── SleepWakeMonitor.swift    # NSWorkspace 깨어남 감지
│   └── NotificationService.swift # UNUserNotificationCenter, 카테고리 등록, 액션 처리
├── Managers/
│   └── WatchlistManager.swift   # 감시 목록 상태, 이벤트 디바운싱, 수면 후 스캔, UserDefaults 영속
└── Views/
    ├── MenuBarMenuView.swift     # 메뉴바 드롭다운 (SwiftUI)
    └── SettingsView.swift        # 감시 목록 편집기 (SwiftUI)
```

## 기술 노트

**파일 감시** — `FileWatcherService`는 `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer` 플래그로 FSEvents C API를 래핑합니다. 이벤트는 2초 레이턴시로 메인 큐에 디스패치되어 버스트를 병합합니다. 디렉터리 이벤트와 dotfile은 `WatchlistManager`에 도달하기 전에 필터링됩니다. 경로별 4초 디바운스 창으로 동일 파일에 여러 이벤트가 연속 발생할 때 중복 알림을 방지합니다.

**iCloud** — `ICloudMonitor`는 `NSMetadataQueryUbiquitousDocumentsScope`와 `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope`로 범위를 설정한 `NSMetadataQuery`를 실행합니다. 실시간 변경은 `NSMetadataQueryDidUpdateNotification`을 통해 전달됩니다. 깨어날 때는 `changedItemsSince(_:)` 메서드가 현재 쿼리 결과를 순회하며 `NSMetadataItemFSContentChangeDateKey`를 저장된 날짜와 비교합니다. 이를 통해 현재 기기에 한 번도 다운로드되지 않은 클라우드 전용 파일의 변경도 감지합니다.

**수면 후 스캔** — `SleepWakeMonitor`는 `NSWorkspace.didWakeNotification`을 감지하고 3초 후 스캔을 시작합니다. 이 지연은 네트워크 재연결 후 iCloud가 메타데이터 인덱스를 갱신할 시간을 확보합니다. 스캔은 로컬 `attributesOfItem(atPath:)[.modificationDate]`와 iCloud 메타데이터 쿼리를 모두 확인해 다운로드된 파일과 클라우드 전용 파일을 모두 커버합니다.

**알림** — `NotificationService`는 `UNUserNotificationCenterDelegate`를 채택하고 두 가지 액션(`OPEN_FILE`, `CLOSE`)이 포함된 `FILE_CHANGE` 카테고리를 등록합니다. 파일 경로는 `userInfo`에 저장되어, 알림 본문 클릭과 파일 열기 버튼 탭 모두 올바른 항목을 열 수 있습니다. `willPresent`가 `.banner`를 반환해 앱이 활성 상태일 때도 알림이 표시됩니다.

## 라이선스

MIT
