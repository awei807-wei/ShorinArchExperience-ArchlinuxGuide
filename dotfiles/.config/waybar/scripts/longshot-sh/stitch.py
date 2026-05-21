#!/usr/bin/env python3
import cv2
import numpy as np
import sys
import os

def build_match_image(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    grad_y = cv2.convertScaleAbs(cv2.Sobel(gray, cv2.CV_16S, 0, 1, ksize=3))
    grad_x = cv2.convertScaleAbs(cv2.Sobel(gray, cv2.CV_16S, 1, 0, ksize=3))
    grad = cv2.addWeighted(grad_y, 0.75, grad_x, 0.25, 0)
    return cv2.GaussianBlur(grad, (3, 3), 0)

def template_positions(y_top, y_bottom, template_h):
    max_y = y_bottom - template_h
    if max_y <= y_top:
        return [y_top]

    span = max_y - y_top
    ratios = (0.0, 0.25, 0.5, 0.75, 0.9)
    return sorted({int(y_top + span * ratio) for ratio in ratios})

def has_texture(template):
    edge_ratio = np.count_nonzero(template > 18) / template.size
    return edge_ratio > 0.002 and float(np.std(template)) > 1.0

def top_candidates(res, template_y, search_y, limit, y_offset=0):
    flat = res.reshape(-1)
    if flat.size == 0:
        return []

    count = min(limit, flat.size)
    partition_at = flat.size - count
    indexes = np.argpartition(flat, partition_at)[partition_at:]
    indexes = indexes[np.argsort(flat[indexes])[::-1]]

    candidates = []
    width = res.shape[1]
    for index in indexes:
        loc_y = int(index // width)
        anchor_y = search_y + y_offset + loc_y
        candidates.append({
            "template_score": float(flat[index]),
            "shift": int(anchor_y - template_y),
            "template_y": int(template_y),
        })
    return candidates

def overlap_score(anchor_grad, curr_grad, x1, x2, shift):
    h = anchor_grad.shape[0]
    if shift < 0 or shift >= h - 5:
        return -1.0

    anchor_overlap = anchor_grad[shift:h, x1:x2]
    curr_overlap = curr_grad[: h - shift, x1:x2]
    if anchor_overlap.size == 0 or curr_overlap.size == 0:
        return -1.0

    anchor_overlap = anchor_overlap[::2, ::2]
    curr_overlap = curr_overlap[::2, ::2]

    diff = cv2.absdiff(anchor_overlap, curr_overlap)
    diff_score = 1.0 - float(np.mean(diff)) / 255.0

    if float(np.std(anchor_overlap)) > 1.0 and float(np.std(curr_overlap)) > 1.0:
        corr = float(cv2.matchTemplate(anchor_overlap, curr_overlap, cv2.TM_CCOEFF_NORMED)[0][0])
        if np.isnan(corr):
            corr = 0.0
    else:
        corr = 0.0

    return max(0.0, min(1.0, corr * 0.65 + diff_score * 0.35))

def is_duplicate_frame(anchor_grad, curr_grad, x1, x2, y1, y2):
    anchor_sample = anchor_grad[y1:y2:4, x1:x2:4]
    curr_sample = curr_grad[y1:y2:4, x1:x2:4]
    if anchor_sample.size == 0 or curr_sample.size == 0:
        return False

    diff = cv2.absdiff(anchor_sample, curr_sample)
    return float(np.mean(diff)) < 1.8

def add_to_clusters(clusters, candidate, score_key, cluster_radius=4):
    for cluster in clusters:
        if abs(cluster["shift"] - candidate["shift"]) <= cluster_radius:
            previous = cluster["templates"].get(candidate["template_y"])
            if previous is None or candidate[score_key] > previous[score_key]:
                cluster["templates"][candidate["template_y"]] = candidate
                values = list(cluster["templates"].values())
                weights = np.array([max(0.01, item[score_key]) for item in values])
                shifts = np.array([item["shift"] for item in values])
                cluster["shift"] = int(round(float(np.average(shifts, weights=weights))))
            return

    clusters.append({
        "shift": candidate["shift"],
        "templates": {candidate["template_y"]: candidate},
    })

def rank_clusters(clusters, last_shift, search_window, score_key):
    ranked = []

    for cluster in clusters:
        values = list(cluster["templates"].values())
        support = len(values)
        avg_score = float(np.mean([item[score_key] for item in values]))
        inertia_bonus = 0.0
        if last_shift > 0:
            distance = abs(cluster["shift"] - last_shift)
            if distance <= search_window:
                inertia_bonus = 0.03
            elif distance <= search_window * 2:
                inertia_bonus = 0.01

        score = avg_score + min(support, 4) * 0.025 + inertia_bonus
        ranked.append({
            "score": min(1.0, score),
            "shift": cluster["shift"],
            "support": support,
        })

    return sorted(ranked, key=lambda item: item["score"], reverse=True)

def find_scroll_match(
    anchor_grad,
    curr_grad,
    x1,
    x2,
    template_y1,
    template_y2,
    search_y1,
    search_y2,
    template_h,
    last_shift,
    search_window,
):
    MAX_OVERLAP_CHECKS = 8
    roi = anchor_grad[search_y1:search_y2, x1:x2]
    if roi.shape[0] < template_h or roi.shape[1] <= 0:
        return None

    clusters = []
    overlap_cache = {}

    for template_y in template_positions(template_y1, template_y2, template_h):
        template = curr_grad[template_y : template_y + template_h, x1:x2]
        if template.shape[0] != template_h or template.shape[1] != roi.shape[1]:
            continue
        if not has_texture(template):
            continue

        res = cv2.matchTemplate(roi, template, cv2.TM_CCOEFF_NORMED)

        candidates = top_candidates(res, template_y, search_y1, 5)

        if last_shift > 0:
            expected_y = template_y + last_shift - search_y1
            y_min = max(0, expected_y - search_window)
            y_max = min(res.shape[0], expected_y + search_window + 1)
            if y_min < y_max:
                local_res = res[y_min:y_max, :]
                candidates.extend(top_candidates(local_res, template_y, search_y1, 2, y_min))

        for candidate in candidates:
            if candidate["shift"] < 0:
                continue

            add_to_clusters(clusters, candidate, "template_score")

    if not clusters:
        return None

    # last_shift 只作为软参考；最终位移需要通过多个模板和整帧重叠区共同支持。
    verified = []
    for candidate in rank_clusters(clusters, last_shift, search_window, "template_score")[:MAX_OVERLAP_CHECKS]:
        shift = candidate["shift"]
        if shift not in overlap_cache:
            overlap_cache[shift] = overlap_score(anchor_grad, curr_grad, x1, x2, shift)

        if overlap_cache[shift] < 0:
            continue

        score = candidate["score"] * 0.45 + overlap_cache[shift] * 0.55
        verified.append({
            "score": min(1.0, score),
            "shift": shift,
            "support": candidate["support"],
        })

    if not verified:
        return None

    return max(verified, key=lambda item: item["score"])

def stitch_video(video_path, output_path):
    if not os.path.exists(video_path):
        return

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("❌ 无法打开视频")
        return

    frames = []
    ret, prev_frame = cap.read()
    if not ret: return

    frames.append(prev_frame)
    # ==========================
    # 核心参数 (手动滚动优化)
    # ==========================
    MIN_SCROLL = 2
    MATCH_CONFIDENCE = 0.52
    RESET_AFTER_MISSES = 2
    fps = cap.get(cv2.CAP_PROP_FPS) or 0
    PROCESS_EVERY = 3 if fps >= 50 else 2 if fps >= 20 else 1
    
    # 忽略上下边缘 (防止浏览器地址栏/状态栏干扰)
    IGNORE_Y_TOP = 0.15 
    IGNORE_Y_BOTTOM = 0.15
    IGNORE_X = 0.15 

    h, w, _ = prev_frame.shape
    
    # 有效特征区
    x1 = int(w * IGNORE_X)
    x2 = int(w * (1 - IGNORE_X))
    y1 = int(h * IGNORE_Y_TOP)
    y2 = int(h * (1 - IGNORE_Y_BOTTOM))
    usable_h = max(1, y2 - y1)
    template_h = min(max(32, int(h * 0.18)), max(16, usable_h // 3))

    print(f"⚡ 正在分析 (梯度匹配模式)...")
    
    last_shift = 0
    miss_count = 0
    SEARCH_WINDOW = 60

    anchor_grad = build_match_image(prev_frame)

    frame_index = 0
    pending_frame = None

    def process_frame(curr_frame):
        nonlocal anchor_grad, last_shift, miss_count
        curr_grad = build_match_image(curr_frame)
        if is_duplicate_frame(anchor_grad, curr_grad, x1, x2, y1, y2):
            miss_count += 1
            if miss_count >= RESET_AFTER_MISSES:
                last_shift = 0
            return

        match = find_scroll_match(
            anchor_grad,
            curr_grad,
            x1,
            x2,
            y1,
            y2,
            y1,
            h,
            template_h,
            last_shift,
            SEARCH_WINDOW,
        )

        if match is None:
            max_val = 0
            shift = 0
        else:
            max_val = match["score"]
            shift = match["shift"]

        # 真实无滚动时，全局最佳通常是 shift=0；此处拒绝它，避免惯性窗口误追加。
        if max_val > MATCH_CONFIDENCE and shift > MIN_SCROLL and shift < (h - 5):
            new_content_start_y = h - shift
            if new_content_start_y < h:
                new_part = curr_frame[new_content_start_y:, :, :]
                frames.append(new_part)
                anchor_grad = curr_grad
                miss_count = 0
                
                if last_shift == 0 or abs(last_shift - shift) > SEARCH_WINDOW * 2:
                    last_shift = shift
                else:
                    last_shift = int(last_shift * 0.6 + shift * 0.4)
        else:
            miss_count += 1
            if miss_count >= RESET_AFTER_MISSES:
                last_shift = 0

    while True:
        ret, curr_frame = cap.read()
        if not ret: break

        frame_index += 1
        if PROCESS_EVERY > 1 and frame_index % PROCESS_EVERY != 0:
            pending_frame = curr_frame
            continue

        process_frame(curr_frame)
        pending_frame = None

    if pending_frame is not None:
        process_frame(pending_frame)

    cap.release()

    if len(frames) > 1:
        try:
            full_image = np.vstack(frames)
            cv2.imwrite(output_path, full_image, [cv2.IMWRITE_PNG_COMPRESSION, 3])
            print(f"🎉 处理完成")
        except Exception as e:
            print(f"❌ 保存失败: {e}")
    else:
        print("⚠️ 未检测到滚动，保存第一帧")
        cv2.imwrite(output_path, frames[0])

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python stitch.py <input_video> <output_image>")
    else:
        stitch_video(sys.argv[1], sys.argv[2])
