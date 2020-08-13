//
//  CollectionViewController.swift
//  IMDB
//
//  Created by abuzeid on 13.08.20.
//  Copyright © 2020 abuzeid. All rights reserved.
//

import RxSwift
import UIKit
import RxCocoa

final class AlbumsController: UICollectionViewController {
    private let viewModel: AlbumsViewModelType
    private let disposeBag = DisposeBag()
    private var albums: [Session] { viewModel.dataList }

    init(viewModel: AlbumsViewModelType) {
        self.viewModel = viewModel
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Unsupported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchBar()
        setupCollection()
        bindToViewModel()
    }
}

// MARK: - setup

private extension AlbumsController {
    private func show(error: String) {
        let alert = UIAlertController(title: nil, message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Str.cancel, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func bindToViewModel() {
        viewModel.reloadFields
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] reload in
                switch reload {
                case .all: self.collectionView.reloadData()
                case let .insertIndexPaths(paths): self.collectionView.insertItems(at: paths)
                }
            })
            .disposed(by: disposeBag)
        viewModel.isDataLoading
            .observeOn(MainScheduler.instance)
            .map { $0 ? CGFloat(50) : CGFloat(0) }
            .bind(onNext: collectionView.updateFooterHeight(height:)).disposed(by: disposeBag)

        viewModel.error
            .observeOn(MainScheduler.instance)
            .bind(onNext: show(error:)).disposed(by: disposeBag)
        viewModel.loadData()
    }

    func setupCollection() {
        title = Str.albumsTitle
        collectionView.register(AlbumCollectionCell.self)
        collectionView.register(ActivityIndicatorFooterView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: ActivityIndicatorFooterView.id)
        collectionView.setCell(type: .twoColumn)
        collectionView.prefetchDataSource = self
    }

    func setupSearchBar() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = Str.search
        viewModel.isSearchLoading
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {
                searchController.searchBar.isLoading = $0
            }).disposed(by: disposeBag)
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
}

// MARK: - UISearchResultsUpdating

extension AlbumsController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard searchController.isActive else {
            viewModel.searchCanceled()
            return
        }
        guard let text = searchController.searchBar.text else { return }
        viewModel.searchFor.onNext(text)
    }
}

// MARK: - UICollectionViewDataSource

extension AlbumsController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albums.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumCollectionCell.identifier, for: indexPath) as! AlbumCollectionCell
        cell.setData(with: albums[indexPath.row])
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionFooter:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: ActivityIndicatorFooterView.id,
                                                                   for: indexPath)

        default:
            fatalError("Unexpected element kind")
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension AlbumsController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        viewModel.prefetchItemsAt(prefetch: true, indexPaths: indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        viewModel.prefetchItemsAt(prefetch: false, indexPaths: indexPaths)
    }
}
