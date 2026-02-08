import os
from flask import Flask, request, render_template_string, send_from_directory, jsonify

app = Flask(__name__)
UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads')
CLIPBOARD_FILE = os.path.join(os.path.dirname(__file__), 'clipboard.txt')

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

if not os.path.exists(CLIPBOARD_FILE):
    with open(CLIPBOARD_FILE, 'w', encoding='utf-8') as f:
        f.write('')

@app.route('/')
def index():
    with open(CLIPBOARD_FILE, 'r', encoding='utf-8') as f:
        clipboard_content = f.read()
    files = os.listdir(UPLOAD_FOLDER)
    return render_template_string(HTML_TEMPLATE, clipboard=clipboard_content, files=files)

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return "No file part", 400
    file = request.files['file']
    if file.filename == '':
        return "No selected file", 400
    file.save(os.path.join(UPLOAD_FOLDER, file.filename))
    return jsonify({"status": "success", "filename": file.filename})

@app.route('/clipboard', methods=['POST'])
def update_clipboard():
    content = request.form.get('content', '')
    with open(CLIPBOARD_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    return jsonify({"status": "success"})

@app.route('/download/<filename>')
def download_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/files')
def list_files():
    files = os.listdir(UPLOAD_FOLDER)
    return jsonify(files)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Piko 局域网分享</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 20px auto; padding: 0 20px; background: #f0f2f5; color: #1c1e21; }
        .card { background: white; padding: 24px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); margin-bottom: 24px; }
        h2 { text-align: center; color: #5c67f2; margin-bottom: 30px; }
        h3 { margin-top: 0; font-size: 1.1rem; color: #444; border-left: 4px solid #5c67f2; padding-left: 10px; }
        textarea { width: 100%; height: 120px; margin: 12px 0; padding: 12px; box-sizing: border-box; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; resize: vertical; background: #fafafa; }
        .btn-group { display: flex; gap: 10px; }
        button { background: #5c67f2; color: white; border: none; padding: 10px 20px; border-radius: 8px; cursor: pointer; font-weight: 600; transition: background 0.2s; flex: 1; }
        button:hover { background: #4a54e1; }
        .file-input-wrapper { position: relative; margin: 12px 0; }
        input[type="file"] { width: 100%; padding: 8px; border: 1px dashed #ccc; border-radius: 8px; }
        ul { list-style: none; padding: 0; margin-top: 12px; }
        li { display: flex; justify-content: space-between; align-items: center; padding: 12px; border-bottom: 1px solid #f0f0f0; }
        li:last-child { border-bottom: none; }
        .file-name { font-size: 14px; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 70%; }
        .download-link { color: #5c67f2; text-decoration: none; font-size: 14px; font-weight: 600; }
        .download-link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h2>Piko 局域网分享 (｡◕‿◕｡)</h2>
    
    <div class="card">
        <h3>文本同步</h3>
        <textarea id="clipboard" placeholder="在此输入文字...">{{ clipboard }}</textarea>
        <div class="btn-group">
            <button onclick="saveText()">保存到云端</button>
            <button style="background:#6c757d" onclick="location.reload()">刷新获取</button>
        </div>
    </div>

    <div class="card">
        <h3>文件上传</h3>
        <div class="file-input-wrapper">
            <input type="file" id="fileInput">
        </div>
        <button onclick="uploadFile()" style="width:100%">开始上传</button>
    </div>

    <div class="card">
        <h3>文件列表</h3>
        <ul id="fileList">
            {% for file in files %}
            <li>
                <span class="file-name">{{ file }}</span>
                <a class="download-link" href="/download/{{ file }}" target="_blank">下载</a>
            </li>
            {% endfor %}
            {% if not files %}
            <li style="color:#999; justify-content:center;">暂无文件</li>
            {% endif %}
        </ul>
    </div>

    <script>
        function saveText() {
            const content = document.getElementById('clipboard').value;
            const btn = event.target;
            btn.innerText = '正在保存...';
            fetch('/clipboard', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'content=' + encodeURIComponent(content)
            }).then(() => {
                btn.innerText = '保存成功！';
                setTimeout(() => btn.innerText = '保存到云端', 2000);
            });
        }

        function uploadFile() {
            const fileInput = document.getElementById('fileInput');
            if (fileInput.files.length === 0) return alert('请选择文件');
            const btn = event.target;
            const originalText = btn.innerText;
            btn.innerText = '正在上传...';
            btn.disabled = true;

            const formData = new FormData();
            formData.append('file', fileInput.files[0]);
            fetch('/upload', { method: 'POST', body: formData })
            .then(res => res.json())
            .then(data => {
                btn.innerText = '上传成功！';
                setTimeout(() => {
                    btn.innerText = originalText;
                    btn.disabled = false;
                    location.reload();
                }, 1000);
            }).catch(err => {
                alert('上传失败');
                btn.innerText = originalText;
                btn.disabled = false;
            });
        }
    </script>
</body>
</html>
"""

if __name__ == '__main__':
    # 局域网开放
    app.run(host='0.0.0.0', port=5000, debug=False)