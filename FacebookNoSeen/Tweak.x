#import <Foundation/Foundation.h>

// Cách 1: Chặn trực tiếp hàm đánh dấu "Đã xem" của các Controller phổ biến.
// Các class này có thể thay đổi tên tùy vào phiên bản Facebook.
%hook FBStoryViewerActionController
- (void)markStoryAsSeen {
    NSLog(@"[FacebookNoSeen] Đã chặn FBStoryViewerActionController markStoryAsSeen");
    // Bỏ trống bên trong để không thực thi lệnh gốc (chặn báo Seen)
}
- (void)markStoryAsSeenWithReason:(id)arg1 {
    NSLog(@"[FacebookNoSeen] Đã chặn markStoryAsSeenWithReason");
}
%end

%hook FBStoryViewerViewController
- (void)_markStoryAsSeen {
    NSLog(@"[FacebookNoSeen] Đã chặn FBStoryViewerViewController _markStoryAsSeen");
}
%end

// Cách 2: Chặn mạnh tay từ gốc Mạng (GraphQL).
// Mọi thao tác trên Facebook (Like, Share, Seen) đều gửi lệnh GraphQL lên máy chủ.
// Ta chặn lệnh nào có chứa chữ "SeenMutation" hoặc "mark_seen".
%hook FBGraphQLService
- (id)performMutation:(id)mutation request:(id)request {
    // mutation thường là một object chứa tên của truy vấn. Ta chuyển nó sang String để kiểm tra.
    NSString *mutationName = [NSString stringWithFormat:@"%@", mutation];
    
    if ([mutationName containsString:@"StoryViewerSeenMutation"] || 
        [mutationName containsString:@"story_seen"] || 
        [mutationName containsString:@"mark_seen"]) {
        
        NSLog(@"[FacebookNoSeen] Đã chặn gửi GraphQL: %@", mutationName);
        return nil; // Không gửi request này đi
    }
    
    // Nếu là các truy vấn khác (Like, Cmt...), cho phép gửi bình thường
    return %orig;
}
%end
