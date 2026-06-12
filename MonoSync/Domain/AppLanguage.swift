import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

extension String {
    func localized(to lang: AppLanguage, _ arguments: CVarArg...) -> String {
        guard let translations = String.localizationTable[self] else {
            return arguments.isEmpty ? self : String(format: self, arguments: arguments)
        }
        let format = translations[lang] ?? self
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }
    
    private static let localizationTable: [String: [AppLanguage: String]] = [
        // 사이드 메뉴 및 섹션 타이틀
        "플레이어": [.korean: "플레이어", .english: "Player"],
        "마이스테이션": [.korean: "마이스테이션", .english: "My Station"],
        "유어스테이션": [.korean: "유어스테이션", .english: "Your Station"],
        "설정": [.korean: "설정", .english: "Settings"],
        
        // 서브타이틀
        "나의 방송국": [.korean: "나의 방송국", .english: "My Station"],
        "친구들의 방송국": [.korean: "친구들의 방송국", .english: "Friends' Stations"],
        "환경 설정": [.korean: "환경 설정", .english: "Preferences"],
        
        // RootView 관련 안내창
        "안내": [.korean: "안내", .english: "Notice"],
        "확인": [.korean: "확인", .english: "OK"],
        "애플뮤직 구독 후 사용할 수 있습니다.": [
            .korean: "애플뮤직 구독 후 사용할 수 있습니다.",
            .english: "Available after subscribing to Apple Music."
        ],
        "현재 재생중입니다. 다른 테이프로 교체 후 진행해주세요.": [
            .korean: "현재 재생중입니다. 다른 테이프로 교체 후 진행해주세요.",
            .english: "Currently playing. Please replace with another tape before proceeding."
        ],
        
        // HomeView & DrawerGridView
        "곡 제목이나 아티스트로 앨범을 찾아보세요": [
            .korean: "곡 제목이나 아티스트로 앨범을 찾아보세요",
            .english: "Search albums by track title or artist"
        ],
        "Apple Music 연결 필요": [.korean: "Apple Music 연결 필요", .english: "Apple Music Connection Required"],
        "앨범 검색을 사용하려면 Apple Music 연결이 필요해요.": [
            .korean: "앨범 검색을 사용하려면 Apple Music 연결이 필요해요.",
            .english: "Apple Music connection is required to search for albums."
        ],
        "취소": [.korean: "취소", .english: "Cancel"],
        "연결": [.korean: "연결", .english: "Connect"],
        "최근 기록": [.korean: "최근 기록", .english: "Recently Played"],
        
        // TrackSearchView
        "음악 찾기": [.korean: "음악 찾기", .english: "Search Music"],
        "노래 제목, 아티스트 검색": [.korean: "노래 제목, 아티스트 검색", .english: "Search song title, artist"],
        "최근 검색어": [.korean: "최근 검색어", .english: "Recent Searches"],
        "검색 결과": [.korean: "검색 결과", .english: "Search Results"],
        "검색 결과가 없습니다.": [.korean: "검색 결과가 없습니다.", .english: "No search results found."],
        "전체 삭제": [.korean: "전체 삭제", .english: "Clear All"],
        "최근 보관함": [.korean: "최근 보관함", .english: "Recent Library"],
        "내 보관함": [.korean: "내 보관함", .english: "My Library"],
        
        // MyStationView & YourStationDetailView
        "스테이션 이름": [.korean: "스테이션 이름", .english: "Station Name"],
        "스테이션 소개": [.korean: "스테이션 소개", .english: "Station Description"],
        "스테이션 이름을 입력하세요": [.korean: "스테이션 이름을 입력하세요", .english: "Enter station name"],
        "스테이션을 소개해보세요": [.korean: "스테이션을 소개해보세요", .english: "Introduce your station"],
        "현재 방송 중": [.korean: "현재 방송 중", .english: "Now Broadcasting"],
        "지금 방송 중인 곡이 없습니다.": [.korean: "지금 방송 중인 곡이 없습니다.", .english: "No track is currently broadcasting."],
        "실시간 댓글": [.korean: "실시간 댓글", .english: "Live Comments"],
        "청취자 %d명": [.korean: "청취자 %d명", .english: "%d Listeners"],
        "아직 댓글이 없습니다.": [.korean: "아직 댓글이 없습니다.", .english: "No comments yet."],
        "댓글 남기기...": [.korean: "댓글 남기기...", .english: "Leave a comment..."],
        "아직 댓글이 없습니다. 첫 댓글을 남겨보세요!": [
            .korean: "아직 댓글이 없습니다. 첫 댓글을 남겨보세요!",
            .english: "No comments yet. Be the first to comment!"
        ],
        "%@의 스테이션": [.korean: "%@의 스테이션", .english: "%@'s Station"],
        
        // YourStationView
        "스테이션 이름, 닉네임 검색": [.korean: "스테이션 이름, 닉네임 검색", .english: "Search station name, nickname"],
        "아직 추가된 친구가 없습니다.": [.korean: "아직 추가된 친구가 없습니다.", .english: "No friends added yet."],
        "방송 중": [.korean: "방송 중", .english: "On Air"],
        "오프라인": [.korean: "오프라인", .english: "Offline"],
        "지금 방송 중인 음악 없음": [.korean: "지금 방송 중인 음악 없음", .english: "No music currently broadcasting"],
        
        // MeView
        "언어": [.korean: "언어", .english: "Language"],
        "프로필": [.korean: "프로필", .english: "Profile"],
        "닉네임": [.korean: "닉네임", .english: "Nickname"],
        "저장": [.korean: "저장", .english: "Save"],
        "다른 친구들에게는 닉네임만 표시됩니다.": [
            .korean: "다른 친구들에게는 닉네임만 표시됩니다.",
            .english: "Only your nickname will be shown to other friends."
        ],
        "Apple Music 연동": [.korean: "Apple Music 연동", .english: "Apple Music Sync"],
        "연결됨": [.korean: "연결됨", .english: "Connected"],
        "연결 안됨": [.korean: "연결 안됨", .english: "Not Connected"],
        "내 초대 링크 공유": [.korean: "내 초대 링크 공유", .english: "Share My Invite Link"],
        "계정": [.korean: "계정", .english: "Account"],
        "앱 정보": [.korean: "앱 정보", .english: "App Info"],
        "친구 설정": [.korean: "친구 설정", .english: "Friend Settings"],
        "요청 허용": [.korean: "요청 허용", .english: "Allow Requests"],
        "공개 범위": [.korean: "공개 범위", .english: "Visibility"],
        "정책": [.korean: "정책", .english: "Policy"],
        "이용약관": [.korean: "이용약관", .english: "Terms of Service"],
        "개인정보 처리방침": [.korean: "개인정보 처리방침", .english: "Privacy Policy"],
        "오픈소스 라이선스": [.korean: "오픈소스 라이선스", .english: "Open Source Licenses"],
        "보기": [.korean: "보기", .english: "View"],
        
        // 공개 범위 값 번역
        "나만 보기": [.korean: "나만 보기", .english: "Private"],
        "친구 공개": [.korean: "친구 공개", .english: "Friends Only"],
        "링크 공개": [.korean: "링크 공개", .english: "Link Only"],
        "모두 공개": [.korean: "모두 공개", .english: "Public"],
        
        // 추가 번역
        "연도 미상": [.korean: "연도 미상", .english: "Unknown Year"],
        "앨범 정보": [.korean: "앨범 정보", .english: "Album Info"],
        "서랍 위치 변경": [.korean: "서랍 위치 변경", .english: "Reorder Drawer"],
        "서랍에서 삭제": [.korean: "서랍에서 삭제", .english: "Remove from Drawer"],
        "앨범 찾기": [.korean: "앨범 찾기", .english: "Search Album"],
        "메모 찾기": [.korean: "메모 찾기", .english: "Search Memo"],
        "찾기": [.korean: "찾기", .english: "Search"],
        "검색 모드": [.korean: "검색 모드", .english: "Search Mode"],
        "앨범 단위로만 불러올 수 있습니다.": [
            .korean: "앨범 단위로만 불러올 수 있습니다.",
            .english: "You can only load entire albums."
        ],
        "나만 볼 수 있는 메모를 검색하세요.": [
            .korean: "나만 볼 수 있는 메모를 검색하세요.",
            .english: "Search your private memos."
        ],
        "아티스트, 앨범 등": [.korean: "아티스트, 앨범 등", .english: "Artist, album, etc."],
        "나의 메모 내용": [.korean: "나의 메모 내용", .english: "My memo content"],
        "%d개의 메모": [.korean: "%d개의 메모", .english: "%d Memos"],
        "작성한 메모가 없습니다.": [.korean: "작성한 메모가 없습니다.", .english: "No memos written yet."],
        "서랍 선택 취소": [.korean: "서랍 선택 취소", .english: "Deselect from Drawer"],
        "서랍에 담기": [.korean: "서랍에 담기", .english: "Add to Drawer"],
        "%@ 선택을 취소했어요": [.korean: "%@ 선택을 취소했어요", .english: "Deselected %@"]
    ]
}
