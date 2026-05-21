#!/bin/sh
"exec" "python3" "$0" "$@"
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path


def local_venv_ready(venv_python):
    if not venv_python.exists():
        return False

    result = subprocess.run(
        [str(venv_python), "-c", "import cv2, numpy"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def find_runtime_dir(script_path):
    candidates = [
        script_path.parent,
        script_path.parent / "longshot-sh",
    ]

    for candidate in candidates:
        if (candidate / "setup.sh").exists() or (candidate / "venv").exists():
            return candidate

    return script_path.parent


def run_local_setup(runtime_dir):
    setup_script = runtime_dir / "setup.sh"
    if not setup_script.exists():
        return False

    print("Longshot: initializing Python environment...", file=sys.stderr)
    result = subprocess.run(
        [str(setup_script)],
        cwd=str(runtime_dir),
        check=False,
    )
    return result.returncode == 0


def reexec_with_local_venv():
    script_path = Path(__file__).resolve()
    runtime_dir = find_runtime_dir(script_path)
    venv_dir = runtime_dir / "venv"
    venv_python = venv_dir / "bin" / "python"

    if not local_venv_ready(venv_python) and not run_local_setup(runtime_dir):
        return

    if Path(sys.prefix).resolve() == venv_dir.resolve():
        return

    os.execv(
        str(venv_python),
        [str(venv_python), str(script_path), *sys.argv[1:]],
    )


reexec_with_local_venv()

import cv2
import numpy as np


KEYCODES = {
    "pagedown": "109",
    "space": "57",
    "down": "108",
}


def is_zh_cn():
    locale_text = " ".join([
        os.environ.get("LANG", ""),
        os.environ.get("LC_ALL", ""),
        os.environ.get("LC_MESSAGES", ""),
    ])
    return "zh_CN" in locale_text


def ui_text():
    if is_zh_cn():
        return {
            "title": "Longshot",
            "capturing": "长截图进行中",
            "capturing_body": "请手动滚动，停止 1 秒后自动拼接...",
            "stitching": "正在拼接...",
            "saved": "长截图完成",
            "saved_body": "已保存并复制到剪贴板",
        }

    return {
        "title": "Longshot",
        "capturing": "Long screenshot in progress",
        "capturing_body": "Scroll manually. Stitching starts after 1 second idle...",
        "stitching": "Stitching...",
        "saved": "Long screenshot complete",
        "saved_body": "Saved and copied to clipboard",
    }


def command_exists(name):
    return shutil.which(name) is not None


def require_commands(names):
    missing = [name for name in names if not command_exists(name)]
    if missing:
        print("Missing command(s): " + ", ".join(missing), file=sys.stderr)
        if "ydotool" in missing:
            print("Install ydotool and make sure ydotoold is running.", file=sys.stderr)
        sys.exit(1)


def ydotool_env(args):
    if not args.ydotool_socket:
        return None
    env = os.environ.copy()
    env["YDOTOOL_SOCKET"] = str(Path(args.ydotool_socket).expanduser())
    return env


def ydotool_help_message(output):
    message = output.strip() or "ydotool failed without an error message."
    return "\n".join([
        message,
        "",
        "ydotool is installed, but the daemon/socket is not ready.",
        "Try:",
        "  systemctl --user enable --now ydotool.service",
        "  ydotool debug",
        "",
        "If the service fails, check /dev/uinput permissions and ydotoold logs:",
        "  systemctl --user status ydotool.service",
        "  journalctl --user -u ydotool.service -n 80 --no-pager",
        "",
        "For a custom daemon socket, run this script with --ydotool-socket PATH.",
    ])


def check_ydotool_ready(args):
    result = subprocess.run(
        ["ydotool", "debug"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=ydotool_env(args),
    )
    if result.returncode != 0:
        raise RuntimeError(ydotool_help_message(result.stdout + result.stderr))


def run_command(command_args, **kwargs):
    return subprocess.run(command_args, check=True, **kwargs)


def notify(title, message="", timeout=3000, icon=None, replace_id=None, print_id=False):
    if not command_exists("notify-send"):
        return None

    command = ["notify-send", "-t", str(timeout)]
    if replace_id is not None:
        command.extend(["-r", str(replace_id)])
    if print_id:
        command.append("-p")
    if icon is not None:
        command.extend(["-i", str(icon)])
    command.append(title)
    if message:
        command.append(message)

    result = subprocess.run(
        command,
        stdout=subprocess.PIPE if print_id else subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if print_id and result.returncode == 0:
        notification_id = result.stdout.strip()
        if notification_id:
            return notification_id
    return replace_id


def open_image(path):
    viewers = [
        ["imv", str(path)],
        ["xdg-open", str(path)],
    ]
    for command in viewers:
        if not command_exists(command[0]):
            continue
        subprocess.Popen(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return True
    return False


def select_geometry():
    result = subprocess.run(
        ["slurp"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    geometry = result.stdout.strip()
    if result.returncode != 0 or not geometry:
        print("Selection cancelled.", file=sys.stderr)
        sys.exit(1)
    return geometry


def capture_png(geometry, path):
    run_command(["grim", "-g", geometry, str(path)], stdout=subprocess.DEVNULL)
    if not path.exists() or path.stat().st_size == 0:
        raise RuntimeError("grim did not produce a valid image")


def run_ydotool(args, command):
    return subprocess.run(
        ["ydotool", *command],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=ydotool_env(args),
    )


def press_key(args, keycode):
    result = run_ydotool(args, ["key", f"{keycode}:1", f"{keycode}:0"])
    if result.returncode != 0:
        raise RuntimeError(ydotool_help_message(result.stdout + result.stderr))


def scroll_wheel(args):
    last_result = None
    for _ in range(max(1, args.wheel_steps)):
        last_result = run_ydotool(
            args,
            ["mousemove", "--wheel", "0", str(args.wheel_y)],
        )
        if last_result.returncode != 0:
            return False, last_result.stdout + last_result.stderr
        if args.wheel_delay > 0:
            time.sleep(args.wheel_delay)
    return True, ""


def scroll_sequence(args):
    if args.scroll_mode == "auto":
        return ["wheel", "pagedown"]
    return [args.scroll_mode]


def perform_scroll(args, mode):
    if mode == "wheel":
        ok, message = scroll_wheel(args)
        if not ok and args.scroll_mode != "auto":
            raise RuntimeError(ydotool_help_message(message))
        return ok

    if mode == "custom":
        press_key(args, args.scroll_keycode)
    else:
        press_key(args, KEYCODES[mode])
    return True


def load_image(path):
    image = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if image is None:
        raise RuntimeError(f"Failed to read image: {path}")
    return image


def crop_feature_area(image, ignore_top, ignore_bottom, ignore_x):
    h, w = image.shape[:2]
    x1 = int(w * ignore_x)
    x2 = int(w * (1.0 - ignore_x))
    y1 = int(h * ignore_top)
    y2 = int(h * (1.0 - ignore_bottom))
    if x2 <= x1 or y2 <= y1:
        return None, (0, 0)
    gray = cv2.cvtColor(image[y1:y2, x1:x2], cv2.COLOR_BGR2GRAY)
    return gray, (x1, y1)


def is_duplicate_frame(prev, curr, ignore_top, ignore_bottom, ignore_x, threshold):
    prev_gray, _ = crop_feature_area(prev, ignore_top, ignore_bottom, ignore_x)
    curr_gray, _ = crop_feature_area(curr, ignore_top, ignore_bottom, ignore_x)
    if prev_gray is None or curr_gray is None or prev_gray.shape != curr_gray.shape:
        return False
    diff = cv2.absdiff(prev_gray[::4, ::4], curr_gray[::4, ::4])
    return float(np.mean(diff)) <= threshold


def shift_overlap_score(prev, curr, shift, args, with_correlation):
    h, w = prev.shape[:2]
    if shift <= args.min_scroll or shift >= h - args.min_overlap:
        return -1.0

    x1 = int(w * args.ignore_x)
    x2 = int(w * (1.0 - args.ignore_x))
    guard_top = int(h * args.ignore_top)
    guard_bottom = int(h * args.ignore_bottom)

    start = guard_top
    end = h - shift - guard_bottom
    if end - start < max(20, args.min_overlap // 2):
        start = 0
        end = h - shift
    if x2 <= x1 or end <= start:
        return -1.0

    prev_gray = cv2.cvtColor(prev, cv2.COLOR_BGR2GRAY)
    curr_gray = cv2.cvtColor(curr, cv2.COLOR_BGR2GRAY)

    prev_overlap = prev_gray[shift + start : shift + end, x1:x2]
    curr_overlap = curr_gray[start:end, x1:x2]
    if prev_overlap.size == 0 or curr_overlap.size == 0:
        return -1.0

    prev_overlap = prev_overlap[:: args.refine_stride, :: args.refine_stride]
    curr_overlap = curr_overlap[:: args.refine_stride, :: args.refine_stride]
    diff = cv2.absdiff(prev_overlap, curr_overlap)
    diff_score = 1.0 - float(np.mean(diff)) / 255.0

    if not with_correlation:
        return diff_score

    if float(np.std(prev_overlap)) <= 1.0 or float(np.std(curr_overlap)) <= 1.0:
        corr = 0.0
    else:
        corr = float(
            cv2.matchTemplate(prev_overlap, curr_overlap, cv2.TM_CCOEFF_NORMED)[0][0]
        )
        if np.isnan(corr):
            corr = 0.0

    return max(0.0, min(1.0, corr * 0.6 + diff_score * 0.4))


def moving_average(values, radius):
    if radius <= 0:
        return values

    radius = min(radius, max(0, (len(values) - 1) // 2))
    if radius <= 0:
        return values

    kernel_size = radius * 2 + 1
    kernel = np.ones(kernel_size, dtype=np.float32) / kernel_size
    return np.convolve(values, kernel, mode="same")


def find_best_seam(prev, curr, shift, args):
    h, w = prev.shape[:2]
    overlap_h = h - shift
    if overlap_h <= 0:
        return 0, 0.0
    if not args.seam_search:
        return overlap_h, 0.0

    x1 = int(w * args.ignore_x)
    x2 = int(w * (1.0 - args.ignore_x))
    if x2 <= x1:
        return overlap_h, 0.0

    top_margin = max(0, min(args.seam_margin, overlap_h // 3))
    bottom_margin = max(0, min(args.seam_margin, overlap_h // 3))
    start = top_margin
    end = overlap_h - bottom_margin
    if end <= start:
        start = 0
        end = overlap_h
    if end <= start:
        return overlap_h, 0.0

    prev_gray = cv2.cvtColor(prev[shift:h, x1:x2], cv2.COLOR_BGR2GRAY)
    curr_gray = cv2.cvtColor(curr[:overlap_h, x1:x2], cv2.COLOR_BGR2GRAY)
    if prev_gray.size == 0 or curr_gray.size == 0:
        return overlap_h, 0.0

    diff_rows = cv2.absdiff(prev_gray, curr_gray).mean(axis=1).astype(np.float32)

    prev_edges = cv2.Sobel(prev_gray, cv2.CV_16S, 0, 1, ksize=3)
    curr_edges = cv2.Sobel(curr_gray, cv2.CV_16S, 0, 1, ksize=3)
    texture_rows = (
        cv2.convertScaleAbs(prev_edges).mean(axis=1)
        + cv2.convertScaleAbs(curr_edges).mean(axis=1)
    ).astype(np.float32) * 0.5

    scores = diff_rows + texture_rows * args.seam_texture_weight
    scores = moving_average(scores, max(0, args.seam_band // 2))
    candidate_scores = scores[start:end]
    if candidate_scores.size == 0:
        return overlap_h, 0.0

    seam = int(start + np.argmin(candidate_scores))
    return seam, float(candidate_scores[seam - start])


def append_with_seam(result, prev, curr, shift, args):
    h = prev.shape[0]
    overlap_h = h - shift
    seam, seam_score = find_best_seam(prev, curr, shift, args)
    seam = max(0, min(seam, overlap_h))

    cut_rows = overlap_h - seam
    if cut_rows > 0:
        if cut_rows >= result.shape[0]:
            result = result[:1, :, :]
        else:
            result = result[:-cut_rows, :, :]

    return np.vstack([result, curr[seam:, :, :]]), seam, seam_score


def add_range(ranges, start, end, min_shift, max_shift):
    start = max(min_shift, int(start))
    end = min(max_shift, int(end))
    if start <= end:
        ranges.append((start, end))


def refine_shift_by_overlap(prev, curr, initial_shift, args):
    h = prev.shape[0]
    min_shift = args.min_scroll + 1
    max_shift = h - args.min_overlap - 1
    if max_shift <= min_shift:
        return None

    ranges = []
    expected = int(round(h * args.expected_shift_ratio))
    add_range(
        ranges,
        expected - args.expected_shift_window,
        expected + args.expected_shift_window,
        min_shift,
        max_shift,
    )
    if initial_shift > args.min_scroll:
        add_range(
            ranges,
            initial_shift - args.refine_window,
            initial_shift + args.refine_window,
            min_shift,
            max_shift,
        )
    elif args.wide_refine:
        add_range(ranges, min_shift, max_shift, min_shift, max_shift)

    if not ranges:
        return None

    coarse = []
    seen = set()
    for start, end in ranges:
        for shift in range(start, end + 1, args.refine_step):
            if shift in seen:
                continue
            seen.add(shift)
            score = shift_overlap_score(prev, curr, shift, args, False)
            if score >= 0:
                coarse.append((score, shift))

    if not coarse:
        return None

    refined = []
    for _, center in sorted(coarse, reverse=True)[: args.refine_top]:
        for shift in range(
            max(min_shift, center - args.refine_step),
            min(max_shift, center + args.refine_step) + 1,
        ):
            score = shift_overlap_score(prev, curr, shift, args, True)
            if score >= 0:
                refined.append((score, shift))

    if not refined:
        return None

    score, shift = max(refined)
    if score < args.min_refine_score:
        return None
    return int(shift), float(score)


def overlap_fallback_match(prev, curr, args):
    if not args.overlap_fallback:
        return None

    refined = refine_shift_by_overlap(prev, curr, 0, args)
    if refined is None:
        return None

    shift, score = refined
    h = prev.shape[0]
    status = "ok"
    if shift <= args.min_scroll:
        status = "no_scroll"
    elif shift >= h - args.min_overlap:
        status = "too_large"

    return {
        "shift": shift,
        "inliers": 0,
        "matches": 0,
        "method": "overlap",
        "refine_score": score,
        "status": status,
    }


def create_detector(method, features):
    if method in ("auto", "sift") and hasattr(cv2, "SIFT_create"):
        return cv2.SIFT_create(nfeatures=features), cv2.NORM_L2, "sift", 0.74
    if method == "sift":
        raise RuntimeError("SIFT is not available in this OpenCV build")
    return cv2.ORB_create(
        nfeatures=features,
        scaleFactor=1.2,
        nlevels=8,
        edgeThreshold=15,
        fastThreshold=7,
    ), cv2.NORM_HAMMING, "orb", 0.82


def detect_and_match(prev, curr, args):
    prev_gray, _ = crop_feature_area(
        prev, args.ignore_top, args.ignore_bottom, args.ignore_x
    )
    curr_gray, _ = crop_feature_area(
        curr, args.ignore_top, args.ignore_bottom, args.ignore_x
    )
    if prev_gray is None or curr_gray is None:
        return None

    detector, norm, method_used, ratio = create_detector(args.method, args.features)
    prev_keypoints, prev_desc = detector.detectAndCompute(prev_gray, None)
    curr_keypoints, curr_desc = detector.detectAndCompute(curr_gray, None)

    if prev_desc is None or curr_desc is None:
        return overlap_fallback_match(prev, curr, args)
    if len(prev_keypoints) < args.min_matches or len(curr_keypoints) < args.min_matches:
        return overlap_fallback_match(prev, curr, args)

    matcher = cv2.BFMatcher(norm)
    pairs = matcher.knnMatch(curr_desc, prev_desc, k=2)
    good = []
    for pair in pairs:
        if len(pair) != 2:
            continue
        first, second = pair
        if first.distance < ratio * second.distance:
            good.append(first)

    if len(good) < args.min_matches:
        return overlap_fallback_match(prev, curr, args)

    curr_pts = np.float32([curr_keypoints[m.queryIdx].pt for m in good])
    prev_pts = np.float32([prev_keypoints[m.trainIdx].pt for m in good])

    homography, mask = cv2.findHomography(
        curr_pts,
        prev_pts,
        cv2.RANSAC,
        args.ransac_threshold,
    )
    if homography is None or mask is None:
        return overlap_fallback_match(prev, curr, args)

    inliers = mask.ravel().astype(bool)
    inlier_count = int(np.count_nonzero(inliers))
    if inlier_count < args.min_inliers:
        return overlap_fallback_match(prev, curr, args)

    curr_inliers = curr_pts[inliers]
    prev_inliers = prev_pts[inliers]
    deltas = prev_inliers - curr_inliers
    dx = float(np.median(deltas[:, 0]))
    dy = float(np.median(deltas[:, 1]))

    refined = refine_shift_by_overlap(prev, curr, dy, args)
    if refined is not None:
        dy, refine_score = refined
    else:
        refine_score = 0.0

    h = prev.shape[0]
    if abs(dx) > args.max_x_drift:
        return overlap_fallback_match(prev, curr, args)
    if dy <= args.min_scroll:
        return {
            "shift": int(round(max(0.0, dy))),
            "inliers": inlier_count,
            "matches": len(good),
            "method": method_used,
            "refine_score": refine_score,
            "status": "no_scroll",
        }
    if dy >= h - args.min_overlap:
        return {
            "shift": int(round(dy)),
            "inliers": inlier_count,
            "matches": len(good),
            "method": method_used,
            "refine_score": refine_score,
            "status": "too_large",
        }

    spread = float(np.std(deltas[:, 1]))
    if spread > args.max_y_spread:
        return overlap_fallback_match(prev, curr, args)

    return {
        "shift": int(round(dy)),
        "inliers": inlier_count,
        "matches": len(good),
        "method": method_used,
        "refine_score": refine_score,
        "status": "ok",
    }


def output_path_from_args(args):
    if args.output:
        return Path(args.output).expanduser()
    save_dir = Path(args.save_dir).expanduser()
    save_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return save_dir / f"longshot_pagedown_{timestamp}.png"


def copy_to_clipboard(path):
    if not command_exists("wl-copy"):
        return
    with open(path, "rb") as image_file:
        subprocess.run(["wl-copy"], stdin=image_file, check=False)


def stitch_match(result, prev, curr, match, args):
    status = match["status"]
    shift = match["shift"]
    if status in ("no_scroll", "too_large"):
        return result, prev, False, status, None, 0.0

    result, seam, seam_score = append_with_seam(result, prev, curr, shift, args)
    return result, curr, True, status, seam, seam_score


def finish_output(result, output_path, frame_paths, notification_id, text, args):
    notification_id = notify(
        text["title"],
        text["stitching"],
        0,
        replace_id=notification_id,
        print_id=notification_id is not None,
    )
    cv2.imwrite(str(output_path), result, [cv2.IMWRITE_PNG_COMPRESSION, 0])
    copy_to_clipboard(output_path)

    if args.keep_frames:
        keep_dir = output_path.with_suffix("")
        keep_dir = keep_dir.parent / (keep_dir.name + "_frames")
        keep_dir.mkdir(parents=True, exist_ok=True)
        for path in frame_paths:
            shutil.copy2(path, keep_dir / path.name)
        print("Kept frames in: " + str(keep_dir))

    notify(
        text["saved"],
        f"{text['saved_body']}: {output_path.name}",
        4000,
        output_path,
        replace_id=notification_id,
    )
    if args.preview:
        open_image(output_path)
    print("Saved: " + str(output_path))


def capture_initial_frame(temp_dir, geometry):
    first_path = temp_dir / "frame_000.png"
    capture_png(geometry, first_path)
    first = load_image(first_path)
    return first, first.copy(), [first_path]


def run_manual_capture(args, temp_dir, geometry, prev, result, frame_paths):
    frame_index = 1
    last_scroll_at = time.monotonic()
    last_report_at = 0.0

    while frame_index <= args.max_pages:
        time.sleep(args.manual_poll)
        current_path = temp_dir / f"frame_{frame_index:03d}_manual.png"
        capture_png(geometry, current_path)
        curr = load_image(current_path)
        frame_paths.append(current_path)

        if is_duplicate_frame(
            prev,
            curr,
            args.ignore_top,
            args.ignore_bottom,
            args.ignore_x,
            args.duplicate_threshold,
        ):
            if time.monotonic() - last_scroll_at >= args.manual_idle_timeout:
                print(f"Stop: no scroll for {args.manual_idle_timeout:.1f}s.")
                break
            continue

        match = detect_and_match(prev, curr, args)
        if match is None:
            if time.monotonic() - last_report_at >= 1.0:
                print("Manual frame: changed but alignment is not stable yet.")
                last_report_at = time.monotonic()
            continue

        result, prev, accepted, status, seam, seam_score = stitch_match(
            result,
            prev,
            curr,
            match,
            args,
        )
        if status == "too_large":
            print("Stop: manual scroll moved too far; overlap is too small for safe stitching.")
            break
        if not accepted:
            if time.monotonic() - last_scroll_at >= args.manual_idle_timeout:
                print(f"Stop: no scroll for {args.manual_idle_timeout:.1f}s.")
                break
            continue

        last_scroll_at = time.monotonic()
        print(
            f"Frame {frame_index}: mode=manual shift={match['shift']}px seam={seam}px "
            f"seam_score={seam_score:.2f} "
            f"inliers={match['inliers']}/{match['matches']} "
            f"method={match['method']} refine={match['refine_score']:.3f}"
        )
        frame_index += 1

    return result, frame_paths


def run_auto_capture(args, temp_dir, geometry, prev, result, frame_paths):
    for index in range(1, args.max_pages + 1):
        match = None
        curr = None
        should_stop = False
        used_mode = None
        modes = scroll_sequence(args)

        for mode in modes:
            if not perform_scroll(args, mode):
                print(f"Frame {index}: scroll mode {mode} failed; trying next mode.")
                continue

            used_mode = mode
            mode_moved = False
            for attempt in range(args.max_failures + 1):
                time.sleep(args.settle if attempt == 0 else args.settle * 1.5)

                suffix = "" if attempt == 0 else f"_retry{attempt}"
                current_path = temp_dir / f"frame_{index:03d}_{mode}{suffix}.png"
                capture_png(geometry, current_path)
                curr = load_image(current_path)
                frame_paths.append(current_path)

                if is_duplicate_frame(
                    prev,
                    curr,
                    args.ignore_top,
                    args.ignore_bottom,
                    args.ignore_x,
                    args.duplicate_threshold,
                ):
                    print(f"Frame {index}: scroll mode {mode} did not move.")
                    if mode == modes[-1]:
                        print(f"Stop: frame {index} is unchanged.")
                        should_stop = True
                    break

                mode_moved = True
                match = detect_and_match(prev, curr, args)
                if match is not None:
                    break

                print(
                    f"Frame {index}: alignment failed "
                    f"({attempt + 1}/{args.max_failures + 1})."
                )

            if should_stop or match is not None:
                break
            if mode_moved:
                break

        if should_stop:
            break
        if match is None or curr is None:
            print("Stop: alignment did not recover.")
            break

        result, prev, accepted, status, seam, seam_score = stitch_match(
            result,
            prev,
            curr,
            match,
            args,
        )
        if status == "no_scroll":
            print("Stop: no more scroll detected.")
            break
        if status == "too_large":
            print("Stop: automatic scroll moved too far; overlap is too small for safe stitching.")
            break
        if not accepted:
            break

        print(
            f"Frame {index}: mode={used_mode} shift={match['shift']}px seam={seam}px "
            f"seam_score={seam_score:.2f} "
            f"inliers={match['inliers']}/{match['matches']} "
            f"method={match['method']} refine={match['refine_score']:.3f}"
        )

    return result, frame_paths


def stitch_with_pagedown(args):
    required_commands = ["grim", "slurp"]
    if args.control_mode == "auto":
        required_commands.append("ydotool")

    require_commands(required_commands)
    if args.control_mode == "auto":
        check_ydotool_ready(args)

    text = ui_text()
    output_path = output_path_from_args(args)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    temp_root = Path(args.temp_dir).expanduser() if args.temp_dir else None
    temp_context = tempfile.TemporaryDirectory(prefix="longshot_pagedown_", dir=temp_root)
    notification_id = None

    with temp_context as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        geometry = args.geometry or select_geometry()
        print("Selected geometry: " + geometry)
        print(f"Starting in {args.start_delay:.1f}s. Keep the target window focused.")
        notification_id = notify(
            text["capturing"],
            text["capturing_body"],
            0,
            print_id=True,
        )
        time.sleep(args.start_delay)

        prev, result, frame_paths = capture_initial_frame(temp_dir, geometry)
        if args.control_mode == "manual":
            result, frame_paths = run_manual_capture(
                args,
                temp_dir,
                geometry,
                prev,
                result,
                frame_paths,
            )
        else:
            result, frame_paths = run_auto_capture(
                args,
                temp_dir,
                geometry,
                prev,
                result,
                frame_paths,
            )

        finish_output(result, output_path, frame_paths, notification_id, text, args)


def build_parser():
    parser = argparse.ArgumentParser(
        description="Capture a lossless scrolling long screenshot with grim."
    )
    parser.add_argument("--geometry", help="grim geometry, for example '0,0 1200x900'")
    parser.add_argument("--output", help="output PNG path")
    parser.add_argument(
        "--save-dir",
        default="~/Pictures/Screenshots/longshots",
        help="output directory when --output is not set",
    )
    parser.add_argument("--temp-dir", help="optional temp parent directory")
    parser.add_argument("--ydotool-socket", help="custom ydotoold socket path")
    parser.add_argument("--max-pages", type=int, default=30)
    parser.add_argument("--max-failures", type=int, default=2)
    parser.add_argument("--start-delay", type=float, default=1.2)
    parser.add_argument("--settle", type=float, default=0.45)
    parser.add_argument("--control-mode", choices=("manual", "auto"), default="manual")
    parser.add_argument("--manual-idle-timeout", type=float, default=1.0)
    parser.add_argument("--manual-poll", type=float, default=0.15)
    parser.add_argument(
        "--scroll-mode",
        choices=("auto", "wheel", "pagedown", "space", "down", "custom"),
        default="auto",
    )
    parser.add_argument("--scroll-keycode", default="109")
    parser.add_argument("--wheel-y", type=int, default=-7)
    parser.add_argument("--wheel-steps", type=int, default=8)
    parser.add_argument("--wheel-delay", type=float, default=0.015)
    parser.add_argument("--method", choices=("auto", "sift", "orb"), default="auto")
    parser.add_argument("--features", type=int, default=5000)
    parser.add_argument("--min-matches", type=int, default=14)
    parser.add_argument("--min-inliers", type=int, default=10)
    parser.add_argument("--ransac-threshold", type=float, default=4.0)
    parser.add_argument("--min-scroll", type=int, default=4)
    parser.add_argument("--min-overlap", type=int, default=80)
    parser.add_argument("--max-x-drift", type=float, default=24.0)
    parser.add_argument("--max-y-spread", type=float, default=8.0)
    parser.add_argument("--expected-shift-ratio", type=float, default=0.78)
    parser.add_argument("--expected-shift-window", type=int, default=180)
    parser.add_argument("--refine-window", type=int, default=96)
    parser.add_argument("--refine-step", type=int, default=4)
    parser.add_argument("--refine-stride", type=int, default=3)
    parser.add_argument("--refine-top", type=int, default=5)
    parser.add_argument("--min-refine-score", type=float, default=0.58)
    parser.add_argument("--no-wide-refine", dest="wide_refine", action="store_false")
    parser.set_defaults(wide_refine=True)
    parser.add_argument("--no-seam-search", dest="seam_search", action="store_false")
    parser.set_defaults(seam_search=True)
    parser.add_argument("--seam-margin", type=int, default=24)
    parser.add_argument("--seam-band", type=int, default=14)
    parser.add_argument("--seam-texture-weight", type=float, default=0.35)
    parser.add_argument("--no-overlap-fallback", dest="overlap_fallback", action="store_false")
    parser.set_defaults(overlap_fallback=True)
    parser.add_argument("--ignore-top", type=float, default=0.08)
    parser.add_argument("--ignore-bottom", type=float, default=0.06)
    parser.add_argument("--ignore-x", type=float, default=0.08)
    parser.add_argument("--duplicate-threshold", type=float, default=1.5)
    parser.add_argument("--no-preview", dest="preview", action="store_false")
    parser.set_defaults(preview=True)
    parser.add_argument("--keep-frames", action="store_true")
    return parser


def main():
    args = build_parser().parse_args()
    try:
        stitch_with_pagedown(args)
    except subprocess.CalledProcessError as exc:
        print(f"Command failed: {' '.join(exc.cmd)}", file=sys.stderr)
        sys.exit(exc.returncode or 1)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
