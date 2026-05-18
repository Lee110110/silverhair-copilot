from collections import defaultdict


class AnnotationRelay:
    def __init__(self):
        self.active_annotations: dict[str, list] = defaultdict(list)

    def record_annotation(self, session_id: str, msg_type: str, payload: dict):
        if msg_type == "annotation.start":
            self.active_annotations[session_id].append({
                "id": payload.get("id", ""),
                "tool": payload.get("tool", "arrow"),
                "color": payload.get("color", "#FF0000"),
                "points": [],
                "started_at": True,
            })
        elif msg_type == "annotation.stroke":
            # Append stroke points to the last annotation
            annotations = self.active_annotations[session_id]
            if annotations:
                points = payload.get("points", [])
                annotations[-1]["points"].extend(points)
        elif msg_type == "annotation.end":
            annotations = self.active_annotations[session_id]
            if annotations:
                annotations[-1]["started_at"] = False
        elif msg_type == "annotation.clear":
            ann_id = payload.get("id")
            self.active_annotations[session_id] = [
                a for a in self.active_annotations[session_id] if a.get("id") != ann_id
            ]
        elif msg_type == "annotation.clear_all":
            self.active_annotations[session_id] = []

    def get_annotations(self, session_id: str) -> list:
        return list(self.active_annotations.get(session_id, []))

    def cleanup(self, session_id: str):
        if session_id in self.active_annotations:
            del self.active_annotations[session_id]