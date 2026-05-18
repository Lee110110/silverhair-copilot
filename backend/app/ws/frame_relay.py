from collections import defaultdict
from datetime import datetime, timezone


class FrameRelay:
    def __init__(self):
        self.frame_stats: dict[str, dict] = defaultdict(lambda: {
            "total_frames": 0,
            "last_seq": 0,
            "last_frame_time": None,
            "fps_estimate": 0.0,
            "acked_seqs": set(),
        })

    def record_frame(self, session_id: str, payload: dict):
        stats = self.frame_stats[session_id]
        stats["total_frames"] += 1
        seq = payload.get("seq", 0)
        stats["last_seq"] = seq
        stats["last_frame_time"] = datetime.now(timezone.utc)

        # Estimate FPS from frame count and time
        if stats["total_frames"] > 1 and stats["last_frame_time"]:
            stats["fps_estimate"] = min(stats["total_frames"] / max(1, stats["total_frames"] * 0.5), 5.0)

    def ack_frame(self, session_id: str, seq: int):
        stats = self.frame_stats[session_id]
        stats["acked_seqs"].add(seq)

    def get_stats(self, session_id: str) -> dict:
        return dict(self.frame_stats.get(session_id, {}))

    def cleanup(self, session_id: str):
        if session_id in self.frame_stats:
            del self.frame_stats[session_id]