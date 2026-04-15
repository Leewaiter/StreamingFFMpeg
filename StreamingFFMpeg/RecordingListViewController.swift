import UIKit
import KSPlayer

// MARK: - 資料模型

struct RecordingSegment: Decodable {
    let start: String
    let duration: Double
    let url: String

    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: start)
    }

    var displayDateTime: String {
        guard let date = startDate else { return start }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "zh_TW")
        return f.string(from: date)
    }

    var displayDuration: String {
        let total = Int(duration)
        if total < 60 { return "\(total) 秒" }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - RecordingListViewController

class RecordingListViewController: UIViewController {

    private let serverBase = "http://27.105.113.156:9996"   // list / 播放
    private let deleteBase = "http://27.105.113.156:9995"   // 刪除（server.py）
    private let recordPath = "cam_recv"
    private var recordings: [RecordingSegment] = []
    private var isLoading = false
    private var isEditMode = false

    private let deleteButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("刪除", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.backgroundColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1)
        b.layer.cornerRadius = 10
        b.clipsToBounds = true
        b.alpha = 0.5
        b.isHidden = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let tableView: UITableView = {
        let t = UITableView()
        t.backgroundColor = UIColor(white: 0.08, alpha: 1)
        t.separatorColor = UIColor(white: 0.2, alpha: 1)
        t.allowsMultipleSelectionDuringEditing = true
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "尚無錄影記錄"
        l.textColor = .gray
        l.font = .systemFont(ofSize: 16)
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .large)
        a.color = .white
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    // MARK: - Navigation Bar 外觀

    private func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.1, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "錄影記錄"
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)

        navigationController?.setNavigationBarHidden(false, animated: false)
        applyNavigationBarAppearance()
        updateNavigationButtons()
        setupLayout()
        loadRecordings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.applyNavigationBarAppearance()
        }
    }

    // MARK: - Navigation Buttons

    private func updateNavigationButtons() {
        let gold = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        if isEditMode {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "完成",
                style: .done,
                target: self,
                action: #selector(onToggleEdit)
            )
            navigationItem.leftBarButtonItem?.tintColor = gold
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(onBack)
            )
            navigationItem.leftBarButtonItem?.tintColor = gold
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "編輯",
                style: .plain,
                target: self,
                action: #selector(onToggleEdit)
            )
            navigationItem.rightBarButtonItem?.tintColor = gold
        }
    }

    @objc private func onBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func onToggleEdit() {
        isEditMode.toggle()
        tableView.setEditing(isEditMode, animated: true)
        deleteButton.isHidden = !isEditMode
        updateNavigationButtons()
        updateDeleteButtonTitle()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        view.addSubview(loadingIndicator)
        view.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            deleteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            deleteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            deleteButton.heightAnchor.constraint(equalToConstant: 50),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: deleteButton.topAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RecordingCell.self, forCellReuseIdentifier: "RecordingCell")
        tableView.rowHeight = 72

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        tableView.refreshControl = refresh

        deleteButton.addTarget(self, action: #selector(onDeleteSelected), for: .touchUpInside)
    }

    // MARK: - 更新刪除按鈕標題

    private func updateDeleteButtonTitle() {
        let count = tableView.indexPathsForSelectedRows?.count ?? 0
        if count > 0 {
            deleteButton.setTitle("刪除（\(count) 個）", for: .normal)
            deleteButton.alpha = 1.0
        } else {
            deleteButton.setTitle("刪除", for: .normal)
            deleteButton.alpha = 0.5
        }
    }

    // MARK: - 載入錄影

    @objc private func onRefresh() { loadRecordings() }

    private func loadRecordings() {
        guard !isLoading else { return }
        isLoading = true
        emptyLabel.isHidden = true
        if recordings.isEmpty { loadingIndicator.startAnimating() }
        guard let url = URL(string: "\(serverBase)/list?path=\(recordPath)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                self.tableView.refreshControl?.endRefreshing()
                if let error = error {
                    self.showError("網路錯誤：\(error.localizedDescription)"); return
                }
                guard let data = data else { return }
                if let text = String(data: data, encoding: .utf8), !text.hasPrefix("[") {
                    self.recordings = []
                    self.tableView.reloadData()
                    self.emptyLabel.text = "尚無錄影記錄"
                    self.emptyLabel.isHidden = false
                    return
                }
                do {
                    let segments = try JSONDecoder().decode([RecordingSegment].self, from: data)
                    self.recordings = segments.sorted { $0.start > $1.start }
                    self.tableView.reloadData()
                    self.emptyLabel.isHidden = !self.recordings.isEmpty
                } catch { self.showError("解析錯誤：\(error.localizedDescription)") }
            }
        }.resume()
    }

    // MARK: - 刪除選取的錄影

    @objc private func onDeleteSelected() {
        guard let selectedPaths = tableView.indexPathsForSelectedRows, !selectedPaths.isEmpty else {
            return
        }
        let count = selectedPaths.count
        let alert = UIAlertController(
            title: "確認刪除",
            message: "確定要刪除 \(count) 個錄影嗎？此操作無法復原。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.performDelete(at: selectedPaths)
        })
        present(alert, animated: true)
    }

    private func performDelete(at indexPaths: [IndexPath]) {
        let segmentsToDelete = indexPaths.map { recordings[$0.row] }
        let group = DispatchGroup()
        var errorMessages: [String] = []

        for segment in segmentsToDelete {
            group.enter()
            deleteRecording(segment: segment) { success, message in
                if !success { errorMessages.append(message) }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // 先退出編輯模式
            self.isEditMode = false
            self.tableView.setEditing(false, animated: true)
            self.deleteButton.isHidden = true
            self.updateNavigationButtons()

            if !errorMessages.isEmpty {
                // ✅ 有錯誤：顯示 alert，按確定後才 reload
                let msg = errorMessages.first ?? "未知錯誤"
                let alert = UIAlertController(title: "刪除失敗", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "確定", style: .default) { [weak self] _ in
                    self?.loadRecordings()
                })
                self.present(alert, animated: true)
            } else {
                // ✅ 全部成功：直接 reload
                self.loadRecordings()
            }
        }
    }

    // ✅ 呼叫 server.py port 9995 刪除，並回傳 server 的錯誤訊息
    private func deleteRecording(segment: RecordingSegment, completion: @escaping (Bool, String) -> Void) {
        guard let encodedStart = segment.start.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(deleteBase)/delete?start=\(encodedStart)") else {
            completion(false, "URL 錯誤")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let error = error {
                    completion(false, "網路錯誤：\(error.localizedDescription)")
                    return
                }
                if (200...299).contains(code) {
                    completion(true, "")
                } else {
                    // 解析 server 回傳的 JSON 錯誤訊息
                    var msg = "HTTP \(code)"
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let serverMsg = json["message"] as? String {
                        msg = serverMsg
                    }
                    completion(false, msg)
                }
            }
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "錯誤", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate / DataSource

extension RecordingListViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recordings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordingCell", for: indexPath) as! RecordingCell
        cell.configure(with: recordings[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditMode {
            updateDeleteButtonTitle()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        let segment = recordings[indexPath.row]
        guard let url = URL(string: segment.url) else { return }
        let vc = RecordingPlayerViewController(url: url, title: segment.displayDateTime, duration: segment.duration)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditMode {
            updateDeleteButtonTitle()
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isEditMode { return nil }
        let action = UIContextualAction(style: .normal, title: "複製URL") { [weak self] _, _, completion in
            UIPasteboard.general.string = self?.recordings[indexPath.row].url
            completion(true)
        }
        action.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - RecordingCell

class RecordingCell: UITableViewCell {

    private let iconView: UIImageView = {
        let i = UIImageView(image: UIImage(systemName: "video.fill"))
        i.tintColor = UIColor(red: 225/255.0, green: 200/255.0, blue: 170/255.0, alpha: 1.0)
        i.contentMode = .scaleAspectFit
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 13)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let chevron: UIImageView = {
        let i = UIImageView(image: UIImage(systemName: "chevron.right"))
        i.tintColor = .darkGray
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.08, alpha: 1)
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 0.15, alpha: 1)
        selectedBackgroundView = bg
        contentView.addSubview(iconView)
        contentView.addSubview(dateLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(chevron)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            dateLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            durationLabel.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            durationLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            durationLabel.trailingAnchor.constraint(equalTo: dateLabel.trailingAnchor),
            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with segment: RecordingSegment) {
        dateLabel.text = segment.displayDateTime
        durationLabel.text = "時長：\(segment.displayDuration)"
    }
}
