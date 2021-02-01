//
//  AlbumDetailViewController.swift
//  Youtube Loader
//
//  Created by isEmpty on 01.02.2021.
//

import UIKit
import CoreData

final class AlbumDetailViewController: UIViewController {
    
    //MARK: - Outlets
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var miniPlayerView: UIView!
    @IBOutlet private weak var bottomView: UIView!
    @IBOutlet private weak var downButton: UIButton!
    
    //MARK: - Properties
    public var sourceProtocol: PlayerSourceProtocol!
    public var album: Album!
    
    private var headerView: StretchyTableHeaderView!
    private var miniPlayer: MiniPlayerViewController!
    private var fetchedResultsController: NSFetchedResultsController<Song>!
    private var dataSource: UITableViewDiffableDataSource<Int, Song>!
    private var snapshot: NSDiffableDataSourceSnapshot<Int, Song>!
    private var searchText = ""
    private var audioPlayer: AudioPlayer {
        return sourceProtocol.audioPlayer
    }
    private var context: NSManagedObjectContext = {
        return (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    }()
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    //MARK: - View Life Cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // If the song is in the audio player, then the player should be shown
        guard let song = audioPlayer.currentSong else { return }
        if let songIndex = dataSource.indexPath(for: song) {
            tableView.selectRow(at: songIndex, animated: true, scrollPosition: .middle)
        }
        tableView.contentInset = UIEdgeInsets(top: tableView.contentInset.top, left: 0, bottom: miniPlayerView.frame.height + 16, right: 0)
        miniPlayerView.isHidden = false
        bottomView.isHidden = false
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        //UI
        configureSearchBar()
        configureTableView()
        configureMiniPlayer()
        miniPlayerView.isHidden = true
        bottomView.isHidden = true
        configureHeaderView()
        downButton.layer.cornerRadius = downButton.frame.height / 2
        
        //Data
        setupFetchedResultsController()
        setupDiffableDataSource()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? MiniPlayerViewController {
            miniPlayer = destination
            miniPlayer.sourceProtocol = sourceProtocol
            miniPlayer?.delegate = self
        }
    }
    
    //MARK: - Actions
    @IBAction private func downButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

//MARK: - Supporting Methods
extension AlbumDetailViewController {
    private func configureSearchBar() {
        searchBar.delegate = self
        
        searchBar.backgroundImage = UIImage()
        guard let searchTextField: UITextField = searchBar.value(forKey: "searchField") as? UITextField else { return }
        guard let imageView = searchTextField.leftView as? UIImageView else { return }
        searchTextField.textColor = .black
        
        let attributeDict = [NSAttributedString.Key.foregroundColor: UIColor.white]
        searchTextField.attributedPlaceholder = NSAttributedString(string: "Search", attributes: attributeDict)
        
        imageView.tintColor = UIColor.white
        imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
        
        searchBar.searchTextField.backgroundColor = .clear
        let view = UIVisualEffectView()
        view.effect = UIBlurEffect(style: .regular)
        view.backgroundColor = UIColor.white.withAlphaComponent(0)
        view.clipsToBounds = true
        view.layer.cornerRadius = 15
        view.translatesAutoresizingMaskIntoConstraints = false
        searchBar.insertSubview(view, at: 0)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: searchTextField.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: searchTextField.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: searchTextField.bottomAnchor),
            view.topAnchor.constraint(equalTo: searchTextField.topAnchor)
        ])
    }
    
    private func configureTableView() {
        tableView.delegate = self
        let nib = UINib(nibName: "SongFromDetailTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "SongFromDetailTableViewCell")
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    private func configureHeaderView() {
        headerView = StretchyTableHeaderView(frame: CGRect(x: 0, y: 0, width: 0, height: 300))
        let url = album.thumbnails!.largeUrl!
        headerView.imageView.af.setImage(withURL: url)
        tableView.tableHeaderView = headerView
    }
    
    private func configureMiniPlayer() {
        miniPlayerView.layer.shadowColor = #colorLiteral(red: 0.5764705882, green: 0.6588235294, blue: 0.7019607843, alpha: 0.1611958471).cgColor
        miniPlayerView.layer.shadowOffset = CGSize(width: 0, height: -11)
        miniPlayerView.layer.shadowRadius = 9
        miniPlayerView.layer.shadowOpacity = 1
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest = Song.fetchRequest()
        
        request.predicate = NSPredicate(format: "album.name == %@", album.name!)
        
        let sort = NSSortDescriptor(key: "dateSave", ascending: true)
        request.sortDescriptors = [sort]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
            setupSnapshot()
        } catch {
            print(error)
        }
    }
    
    private func setupSnapshot() {
        snapshot = NSDiffableDataSourceSnapshot<Int, Song>()
        snapshot.appendSections([0])
        snapshot.appendItems(fetchedResultsController.fetchedObjects ?? [])
        miniPlayer.songs = snapshot.itemIdentifiers
        DispatchQueue.main.async {
            self.dataSource?.apply(self.snapshot, animatingDifferences: true)
        }
    }
        
    private func setupDiffableDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Song>(tableView: tableView, cellProvider: { (tableView, indexPath, song) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SongFromDetailTableViewCell") as! SongFromDetailTableViewCell
            
            if let imageUrl = song.thumbnails?.smallUrl {
                cell.songImageView.af.setImage(withURL: imageUrl, placeholderImage: #imageLiteral(resourceName: "music_placeholder"))
                cell.backgroundBlurImage.af.setImage(withURL: imageUrl, placeholderImage: #imageLiteral(resourceName: "music_placeholder"))
            }
            cell.titleLabel.text = song.name
            cell.descriptionLabel.text = song.author?.name
            cell.indexLabel.text = String(indexPath.row + 1)
            
            return cell
        })
        
        setupSnapshot()
    }
}

//MARK: - NSFetchedResultsControllerDelegate
extension AlbumDetailViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        setupSnapshot()
    }
}

//MARK: - MiniPlayerDelegate
extension AlbumDetailViewController: MiniPlayerDelegate {
    func didSelectedItem(_ item: Song?) {
        guard let song = item else { return }
        guard let songIndex = dataSource.indexPath(for: song) else { return }
        tableView.selectRow(at: songIndex, animated: true, scrollPosition: .none)
    }
    
    func expandSong(song: Song?) {
        let storyboard = UIStoryboard(name: "Player", bundle: nil)
        guard let playerController = storyboard.instantiateInitialViewController() as? PlayerViewController else { return }
        playerController.sourceProtocol = sourceProtocol
        playerController.modalPresentationStyle = .currentContext
        present(playerController, animated: true, completion: nil)
    }
}

//MARK: - UITableViewDelegate & UIScrollViewDelegate
extension AlbumDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = audioPlayer.currentSong {
            guard let songIndex = dataSource.indexPath(for: song) else { return }
            guard songIndex != indexPath else { return }
        }
        miniPlayer.play(at: indexPath.row)
        
        if miniPlayerView.isHidden {
            tableView.contentInset = UIEdgeInsets(top: tableView.contentInset.top, left: 0, bottom: miniPlayerView.frame.height + 8, right: 0)
            
            UIView.transition(with: miniPlayerView, duration: 0.3, options: .transitionCrossDissolve) {
                self.miniPlayerView.isHidden = false
                self.bottomView.isHidden = false
            } completion: { (_) in }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        headerView.scrollViewDidScroll(scrollView: scrollView)
    }
}

//MARK: - UISearchBarDelegate
extension AlbumDetailViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(search), object: nil)
        self.searchText = searchText
        perform(#selector(search), with: nil, afterDelay: 0.5)
    }
    
    @objc private func search() {
        setupFetchedResultsController()
    }
}
