//
//  MainViewModel.swift
//  WeatherAPIwithMVVM
//
//  Created by 허광호 on 2020/09/18.
//

import Foundation
import RxFlow

enum MainInput {
    case refresh
    case search
    case cellSelect(Int)
    case cellDelete(CityInfo)
}

class MainViewModel: ViewModelType, Stepper {
    // MARK: - Stepper
    var steps = PublishRelay<Step>()
    
    let disposeBag = DisposeBag()
    
    // MARK: - Properties
    /// 서버에서 받아온 도시 리스트
    var listCellData: [CityInfo] = []
    /// 테이블 뷰에 보여줄 도시 리스트
    let cityRelay = BehaviorRelay<[CityInfo]>(value: [])

    // MARK: - ViewModelType Protocol
    typealias ViewModel = MainViewModel

    struct Input {
        let action: Observable<MainInput>
    }

    struct Output {
        let itemList: Observable<[CityInfo]>
    }

    func transform(req: ViewModel.Input) -> ViewModel.Output {
        req.action.bind(onNext: actionProcess).disposed(by: disposeBag)
        
        return Output(itemList: cityRelay.asObservable())
    }
    
    /// 터치 액션 이벤트
    func actionProcess(action: MainInput) {
        switch action {
        case .refresh:
            if let data = UserDefaults.standard.value(forKey: "CityIdList") as? [Int] {
                setUpData(data)
            }
        case .search:
            self.steps.accept(AppStep.search)
        case .cellSelect(let index):
            self.steps.accept(AppStep.detail(data: cityRelay.value, index: index))
        case .cellDelete(let city):
            guard var data = UserDefaults.standard.value(forKey: "CityIdList") as? [Int] else { return }
            for i in 0..<data.count {
                if data[i] == city.id {
                    data.remove(at: i)
                    break
                }
            }
            UserDefaults.standard.set(data, forKey: "CityIdList")
            setUpData(data)
        }
    }
}

extension MainViewModel {
    /// 데이터 불러오기
    func setUpData(_ cityId: [Int?]) {
        let result: Single<BaseWeatherAPI> = NetworkService.loadData(type: .weather(cityId))

        result.subscribe { [weak self] event in
            guard let `self` = self else { return }
            switch event {
            case .success(let model):
                self.listCellData = [] // 중복방지하면서 갱신하기 위해 리스트 배열 비워주기 (개선 필요)
                model.list?.forEach {
                    self.listCellData.append(model.send($0))
                }
                self.cityRelay.accept(self.listCellData)
                UserDefaults.standard.set(self.listCellData.map { $0.id }, forKey: "CityIdList")
            case .error(let error):
                ToastMessage.shared.showToast(error.localizedDescription)
            }
        }.disposed(by: disposeBag)
    }
}
