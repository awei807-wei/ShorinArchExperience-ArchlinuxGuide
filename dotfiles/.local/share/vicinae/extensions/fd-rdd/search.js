/* eslint-disable no-undef */
/* global fetch */

const React = require("react");
const nodePath = require("node:path");
const {
	List,
	ActionPanel,
	Action,
	Icon,
	getPreferenceValues,
} = require("@vicinae/api");

const LIMIT = 50;
const DEFAULT_PORT = 6060;

function safeBasename(p) {
	try {
		// fd-rdd returns Linux paths, but handle backslashes just in case.
		const normalized = String(p).replaceAll("\\\\", "/");
		return nodePath.posix.basename(normalized);
	} catch {
		return String(p);
	}
}

function parsePort(value) {
	const n = Number.parseInt(String(value ?? ""), 10);
	if (Number.isFinite(n) && n >= 1 && n <= 65535) return n;
	return DEFAULT_PORT;
}

function formatBytes(bytes) {
	const b = Number(bytes);
	if (!Number.isFinite(b) || b <= 0) return "0 bytes";
	const units = ["bytes", "KB", "MB", "GB", "TB", "PB"];
	const base = 1024;
	const unitIndex = Math.min(
		units.length - 1,
		Math.floor(Math.log(b) / Math.log(base)),
	);
	const size = b / Math.pow(base, unitIndex);

	let value;
	if (unitIndex === 0) value = `${Math.floor(size)}`;
	else if (size >= 100) value = size.toFixed(0);
	else if (size >= 10) value = size.toFixed(1);
	else value = size.toFixed(2);

	return `${value} ${units[unitIndex]}`;
}

function buildUrl(port, query) {
	const params = new URLSearchParams();
	params.set("q", query);
	params.set("limit", String(LIMIT));
	return `http://127.0.0.1:${port}/search?${params.toString()}`;
}

async function httpGetJson(url, signal) {
	if (typeof fetch === "function") {
		const res = await fetch(url, { signal });
		if (!res.ok) throw new Error(`HTTP ${res.status}`);
		return await res.json();
	}

	// Fallback for older Node runtimes without global fetch.
	const http = require("node:http");
	return new Promise((resolve, reject) => {
		const req = http.get(url, (res) => {
			let body = "";
			res.setEncoding("utf8");
			res.on("data", (chunk) => (body += chunk));
			res.on("end", () => {
				try {
					if (res.statusCode && res.statusCode >= 400) {
						reject(new Error(`HTTP ${res.statusCode}`));
						return;
					}
					resolve(JSON.parse(body));
				} catch (e) {
					reject(e);
				}
			});
		});
		req.on("error", reject);
		if (signal) {
			signal.addEventListener(
				"abort",
				() => {
					req.destroy(new Error("aborted"));
				},
				{ once: true },
			);
		}
	});
}

function SearchCommand() {
	const prefs = getPreferenceValues();
	const port = parsePort(prefs.fd_rdd_port);

	const [query, setQuery] = React.useState("");
	const [items, setItems] = React.useState([]);
	const [isLoading, setIsLoading] = React.useState(false);
	const [errorText, setErrorText] = React.useState("");

	const abortRef = React.useRef(null);
	const seqRef = React.useRef(0);

	React.useEffect(() => {
		const q = query.trim();

		seqRef.current += 1;
		const seq = seqRef.current;

		if (abortRef.current) {
			abortRef.current.abort();
			abortRef.current = null;
		}

		if (!q) {
			setIsLoading(false);
			setErrorText("");
			setItems([]);
			return;
		}

		const controller = new AbortController();
		abortRef.current = controller;

		setIsLoading(true);
		setErrorText("");

		const url = buildUrl(port, q);

		httpGetJson(url, controller.signal)
			.then((json) => {
				if (seqRef.current !== seq) return;
				if (!Array.isArray(json)) {
					setItems([]);
					setErrorText("Invalid response");
					return;
				}

				const next = [];
				for (const row of json) {
					if (!row || typeof row.path !== "string") continue;
					const size = typeof row.size === "number" ? row.size : Number(row.size);
					next.push({ path: row.path, size: Number.isFinite(size) ? size : 0 });
					if (next.length >= LIMIT) break;
				}
				setItems(next);
			})
			.catch((err) => {
				if (controller.signal.aborted) return;
				if (seqRef.current !== seq) return;
				setItems([]);
				setErrorText(err?.message ? String(err.message) : String(err));
			})
			.finally(() => {
				if (seqRef.current !== seq) return;
				setIsLoading(false);
			});
	}, [query, port]);

	const emptyView = !query.trim()
		? React.createElement(List.EmptyView, {
				icon: Icon.MagnifyingGlass,
				title: "请输入关键词",
				description: "支持 fd-rdd 的通配符语义，例如 (*test*.md)*",
			})
		: errorText
			? React.createElement(List.EmptyView, {
					icon: Icon.Exclamationmark,
					title: "fd-rdd 不可用",
					description: `无法请求 127.0.0.1:${port}（${errorText}）`,
				})
			: React.createElement(List.EmptyView, {
					icon: Icon.MagnifyingGlass,
					title: "无结果",
					description: "尝试修改关键词或通配符。",
				});

	const children = [];
	if (items.length === 0) {
		children.push(emptyView);
	} else {
		children.push(
			React.createElement(
				List.Section,
				{ key: "results", title: `Results (${items.length})` },
				items.map((it) =>
					React.createElement(List.Item, {
						key: it.path,
						id: it.path,
						title: safeBasename(it.path),
						subtitle: it.path,
						accessories: [{ text: formatBytes(it.size) }],
						actions: React.createElement(
							ActionPanel,
							null,
							React.createElement(
								ActionPanel.Section,
								null,
								React.createElement(Action.Open, {
									title: "Open",
									target: it.path,
								}),
								React.createElement(Action.ShowInFinder, {
									title: "Show in Folder",
									path: it.path,
								}),
								React.createElement(Action.CopyToClipboard, {
									title: "Copy Path",
									content: it.path,
								}),
							),
						),
					}),
				),
			),
		);
	}

	return React.createElement(
		List,
		{
			filtering: false,
			isLoading,
			throttle: true,
			searchBarPlaceholder: "fd-rdd query (supports glob)",
			onSearchTextChange: setQuery,
		},
		...children,
	);
}

module.exports = { default: SearchCommand };
