//
//  ViewController.swift
//  JNews
//
//  Created by ChenKaijie on 16/7/9.
//  Copyright © 2016年 com.ckj. All rights reserved.
//

import UIKit
import Alamofire

let WIDTH = UIScreen.mainScreen().bounds.size.width
let HEIGHT = UIScreen.mainScreen().bounds.size.height
let Base_URL = "http://139.129.133.227:8080/"

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MenuViewDelegate, MainBottomTableViewCellDelegate {
    @IBOutlet weak var mainTV: UITableView!
    @IBOutlet weak var menuButton: UIButton!
    let bottomCellHeight: CGFloat = 280
    var topCellHeight: CGFloat = 0
    var markFirstCellHeight: CGFloat = 0 //记录第一条新闻的高度
    var lastOffset: CGFloat = 0
    var type: TimeType = TimeType.Day
    var newsArray = Array<NewsModel>()
    
    //MARK: - Life Circle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register Nib
        self.mainTV.registerNib(UINib.init(nibName: "MainTopTableViewCell", bundle: NSBundle.mainBundle()), forCellReuseIdentifier: "Top")
        self.mainTV.registerNib(UINib.init(nibName: "MainTableViewCell", bundle: NSBundle.mainBundle()), forCellReuseIdentifier: "Another")
        self.mainTV.registerNib(UINib.init(nibName: "MainBottomTableViewCell", bundle: NSBundle.mainBundle()), forCellReuseIdentifier: "Bottom")
        // Cell Height
        self.topCellHeight = HEIGHT - 10
        
        // 默认是true，UIScrollView及其子类，会在顶部和底部预留空白
        self.automaticallyAdjustsScrollViewInsets = false
        
        // 读取数据
        let newsManager = NewsHelpers.shareManager
        // 先从本地取数据
        let submitString = String.getSubmitTimeString()
        var dayOrNight: NSInteger = 0
        
        if self.validateTimeIsDay() {
            dayOrNight = 0
            newsArray = newsManager.findNews(submitString, dayOrNight: dayOrNight)
        }
        else{
            dayOrNight = 1
            newsArray = newsManager.findNews(submitString, dayOrNight: dayOrNight)
        }
        
        if newsArray.count == 0 {
            let loadingView = LoadingView()
            loadingView.show()
            // 今天的新闻本地没有数据，从网上取
            Alamofire.request(.POST, "\(Base_URL)somedayNews", parameters: ["newsDate":submitString, "dayOrNight":"\(dayOrNight)"], encoding: .JSON, headers: ["Content-Type":"application/json"])
                .responseJSON { (response) in
                    guard response.result.error == nil else {
                        print("Error: ", response.result.error!)
                        return
                    }
                    let dataArray = response.result.value as! NSArray
                    if dataArray.count != 0 {
                        for dataDic in dataArray {
                            let dictionary = dataDic as! NSDictionary
                            
                            let model = NewsModel()
                            model.newsType = dictionary.objectForKey("newsType") as? NSNumber
                            model.newsTitle = dictionary.objectForKey("newsTitle") as? String
                            model.commNum = dictionary.objectForKey("commNum") as? NSNumber
                            model.newsContent = dictionary.objectForKey("newsContent") as? String
                            model.isRead = dictionary.objectForKey("isRead") as? NSNumber
                            model.newsDate = dictionary.objectForKey("newsDate") as? String
                            model.dayOrNight = dictionary.objectForKey("dayOrNight") as? NSNumber
                            model.newsID = dictionary.objectForKey("_id") as? String
                            model.newsPicture = dictionary.objectForKey("newsPicture") as? String
                            
                            // 存储到数据库
                            newsManager.addNews(model)
                            // 添加到 newsArray
                            self.newsArray.append(model)
                        }
                        loadingView.dismiss()
                        self.mainTV.reloadData()
                    }
                    else {
                        // 服务器今天也没有新闻，从本地数据库取最新的新闻
                        self.newsArray = newsManager.findLastestNews()
                        if self.newsArray.count == 0 {
                            // 本地也没有数据，取一定有新闻的一天
                            Alamofire.request(.POST, "\(Base_URL)somedayNews", parameters: ["newsDate":"2016.08.02", "dayOrNight":"0"], encoding: .JSON, headers: ["Content-Type":"application/json"])
                                .responseJSON { (response) in
                                    guard response.result.error == nil else {
                                        print("Error: ", response.result.error!)
                                        return
                                    }
                                    let dataArray = response.result.value as! NSArray
                                    if dataArray.count != 0 {
                                        for dataDic in dataArray {
                                            let dictionary = dataDic as! NSDictionary
                                            
                                            let model = NewsModel()
                                            model.newsType = dictionary.objectForKey("newsType") as? NSNumber
                                            model.newsTitle = dictionary.objectForKey("newsTitle") as? String
                                            model.commNum = dictionary.objectForKey("commNum") as? NSNumber
                                            model.newsContent = dictionary.objectForKey("newsContent") as? String
                                            model.isRead = dictionary.objectForKey("isRead") as? NSNumber
                                            model.newsDate = dictionary.objectForKey("newsDate") as? String
                                            model.dayOrNight = dictionary.objectForKey("dayOrNight") as? NSNumber
                                            model.newsID = dictionary.objectForKey("_id") as? String
                                            model.newsPicture = dictionary.objectForKey("newsPicture") as? String
                                            
                                            // 存储到数据库
                                            newsManager.addNews(model)
                                            // 添加到 newsArray
                                            self.newsArray.append(model)
                                        }
                                        loadingView.dismiss()
                                        self.mainTV.reloadData()
                                    }
                            }
                        }
                        else {
                            loadingView.dismiss()
                            self.mainTV.reloadData()
                        }
                    }
            }
        }
        
        // 后台开启任务，从数据库清除6天前的新闻
//        self.performSelectorInBackground(#selector(ViewController.deleteNewsData), withObject: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let newsVC = segue.destinationViewController as! NewsViewController
        newsVC.modelArray = self.newsArray
        newsVC.currentRow = sender as? NSIndexPath
        // AnimationClosure
        newsVC.selectedClosure = {(selectedArray) in
            let _ = selectedArray.map({[unowned self] (row) -> Int in
                // 筛选在visiableCells的cell
                if row == 0 {
                    guard let cell = self.mainTV.cellForRowAtIndexPath(NSIndexPath.init(forRow: row, inSection: 0)) as? MainTopTableViewCell else {
                        return row
                    }
                    // 执行动画，如果已读则不执行
                    let model = self.newsArray[row] as NewsModel
                    guard model.isRead!.intValue == 0 else {
                        cell.number.textColor = UIColor.whiteColor()
                        cell.numberView.backgroundColor = cell.color
                        return row
                    }
                    cell.animationStart()
                }
                else {
                    guard let cell = self.mainTV.cellForRowAtIndexPath(NSIndexPath.init(forRow: row, inSection: 0)) as? MainTableViewCell else {
                        return row
                    }
                    let model = self.newsArray[row] as NewsModel
                    guard model.isRead!.intValue == 0 else {
                        return row
                    }
                    cell.animationStart()
                }
                
                // 设置新闻已读
                let model = self.newsArray[row] as NewsModel
                model.isRead = NSNumber.init(short: 1)
                
                // 更新到数据库
                let newsManager = NewsHelpers.shareManager
                newsManager.updateNews(model.newsID!)
                
                // 如果BottomViewCell存在的话执行动画
                guard let bottomCell = self.mainTV.cellForRowAtIndexPath(NSIndexPath.init(forRow: self.newsArray.count, inSection: 0)) as? MainBottomTableViewCell else {
                    return row
                }
                bottomCell.animationStart(row)
                return row
                })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - UITableViewDataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.newsArray.count == 0 {
            return 0
        }
        return self.newsArray.count + 1;
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return self.topCellHeight
        }
        else if indexPath.row == self.newsArray.count {
            return self.bottomCellHeight
        }
        else {
            let context = self.newsArray[indexPath.row].newsTitle! as String
            let height = context.getHeight(context, margin: 65, fontSize: 17)
            return (height < 21) ? 110 : 110 - 21 + height;
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            // Top Cell
            let cell = tableView.dequeueReusableCellWithIdentifier("Top", forIndexPath: indexPath) as! MainTopTableViewCell;
            cell.model = self.newsArray[indexPath.row]
            return cell;
        }
        else if indexPath.row == self.newsArray.count {
            // Bottom Cell
            let cell = tableView.dequeueReusableCellWithIdentifier("Bottom", forIndexPath: indexPath) as! MainBottomTableViewCell;
            cell.delegate = self
            cell.modelArray = self.newsArray
            
            return cell;
        }
        else {
            let cell = tableView.dequeueReusableCellWithIdentifier("Another", forIndexPath: indexPath) as! MainTableViewCell;
            cell.indexPath = indexPath
            cell.model = self.newsArray[indexPath.row]
            return cell;
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard indexPath.row != self.cellArray.count else {
            // 点击最后一个Cell 没有效果
            return
        }
        self.performSegueWithIdentifier("news", sender: indexPath)
        
        // 选中之后消除痕迹
        guard indexPath.row != 0 else {
            return
        }
        self.performSelector(#selector(ViewController.deselect(_:)), withObject: indexPath, afterDelay: 0.3)
    }

    //MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset_y = scrollView.contentOffset.y;
        
        // contentOffset.y < 0
        guard let cell = self.mainTV.cellForRowAtIndexPath(NSIndexPath.init(forRow: 0, inSection: 0)) as? MainTopTableViewCell else {
            // MainTopTableViewCell 已经不在visiableCells数组
        
            let distance = self.topCellHeight - self.markFirstCellHeight
            if offset_y > distance {
                if self.lastOffset > offset_y {
                    self.menuButton.hidden = false
                }
                else{
                    self.menuButton.hidden = true
                }
            }
            else {
                self.menuButton.hidden = false
            }
            
            self.lastOffset = offset_y
            return
        }
        if offset_y < 0 {
            // BackgroundImage
            var imageRect = cell.backgroundImage.frame
            imageRect.origin.y = offset_y
            imageRect.size.height = self.topCellHeight - offset_y
            cell.backgroundImage.frame = imageRect
            // Date And Time
            var dateRect = cell.currentDate.frame
            var timeRect = cell.currentTime.frame
            dateRect.origin.y = offset_y + 12
            timeRect.origin.y = offset_y + 49
            cell.currentDate.frame = dateRect
            cell.currentTime.frame = timeRect
        }
        else {
            // 恢复到原始状态
            cell.backgroundImage.frame = CGRectMake(0, 0, WIDTH, self.topCellHeight)
            cell.currentDate.frame = CGRectMake(12, 12, 110, 29)
            cell.currentTime.frame = CGRectMake(12, 49, 110, 21)
            // Mark Height
            self.markFirstCellHeight = cell.heightConstraint.constant
        }
        
        // 是否隐藏菜单按钮
        let distance = self.topCellHeight - self.markFirstCellHeight
        if offset_y > distance {
            if self.lastOffset > offset_y {
                self.menuButton.hidden = false
            }
            else{
                self.menuButton.hidden = true
            }
        }
        else {
            self.menuButton.hidden = false
        }
        self.lastOffset = offset_y
    }
    
    //MARK: - MenuViewDelegate
    func menuViewCallBack() {
        guard let data: NSData = UserDefault.objectForKey("SelectedItem") as? NSData else {
            return
        }
        // 获取选择新闻日期
        let calendar = NSCalendar.init(calendarIdentifier: NSCalendarIdentifierGregorian)
        let components = calendar?.components([.Day, .Month, .Year, .Weekday], fromDate: NSDate())
        let dateFormate = NSDateFormatter()
        dateFormate.dateFormat = "yyyy.MM.dd"
        
        var dayOrNight: NSInteger = 0
        let indexPath = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! NSIndexPath
        if self.type == TimeType.Day {
            // 白天
            switch indexPath.section {
            case 0:
                components?.day = components!.day - 5
                dayOrNight = 1
            case 1:
                components?.day = components!.day - 4
                if indexPath.row == 0 {
                    dayOrNight = 0
                }
                else {
                    dayOrNight = 1
                }
            case 2:
                components?.day = components!.day - 3
                if indexPath.row == 0 {
                    dayOrNight = 0
                }
                else {
                    dayOrNight = 1
                }
            case 3:
                components?.day = components!.day - 2
                if indexPath.row == 0 {
                    dayOrNight = 0
                }
                else {
                    dayOrNight = 1
                }
            case 4:
                components?.day = components!.day - 1
                if indexPath.row == 0 {
                    dayOrNight = 0
                }
                else {
                    dayOrNight = 1
                }
            case 5:
                dayOrNight = 0
            default:
                print("Error");
            }
        }
        else {
            // 黑夜
            switch indexPath.section {
            case 0:
                components?.day = components!.day - 4
            case 1:
                components?.day = components!.day - 3
            case 2:
                components?.day = components!.day - 2
            case 3:
                components?.day = components!.day - 1
            case 4:
                print("Nothing to do")
            default:
                print("Error");
            }
            if indexPath.row == 0 {
                dayOrNight = 0
            }
            else {
                dayOrNight = 1
            }
        }
        
        let submitString = dateFormate.stringFromDate(calendar!.dateFromComponents(components!)!)
        // 读取CoreData数据
        let newsManager = NewsHelpers.shareManager
        newsArray.removeAll()
        newsArray = newsManager.findNews(submitString, dayOrNight: dayOrNight)
        if newsArray.count == 0 {
            // 本地没有数据，从网络获取
            let loadingView = LoadingView()
            loadingView.show()
            Alamofire.request(.POST, "\(Base_URL)somedayNews", parameters: ["newsDate":submitString, "dayOrNight":"\(dayOrNight)"], encoding: .JSON, headers: ["Content-Type":"application/json"])
                .responseJSON { (response) in
                    guard response.result.error == nil else {
                        print("Error: ", response.result.error!)
                        return
                    }
                    let dataArray = response.result.value as! NSArray
                    if dataArray.count != 0 {
                        for dataDic in dataArray {
                            let dictionary = dataDic as! NSDictionary
                            
                            let model = NewsModel()
                            model.newsType = dictionary.objectForKey("newsType") as? NSNumber
                            model.newsTitle = dictionary.objectForKey("newsTitle") as? String
                            model.commNum = dictionary.objectForKey("commNum") as? NSNumber
                            model.newsContent = dictionary.objectForKey("newsContent") as? String
                            model.isRead = dictionary.objectForKey("isRead") as? NSNumber
                            model.newsDate = dictionary.objectForKey("newsDate") as? String
                            model.dayOrNight = dictionary.objectForKey("dayOrNight") as? NSNumber
                            model.newsID = dictionary.objectForKey("_id") as? String
                            model.newsPicture = dictionary.objectForKey("newsPicture") as? String
                            
                            // 存储到数据库
                            newsManager.addNews(model)
                            // 添加到 newsArray
                            self.newsArray.append(model)
                        }
                    }
                    else {
                        // 服务器今天也没有新闻，从本地数据库取最新的新闻
                        self.newsArray = newsManager.findLastestNews()
                    }
                    loadingView.dismiss()
                    self.mainTV.reloadData()
            }
        }
        else {
            self.mainTV.reloadData()
        }
    }
    
    //MARK: - MainBottomTableViewCellDelegate
    func listButtonCallBack() {
        if !self.validateTimeIsDay() {
            self.type = TimeType.Night
        }
        else {
            self.type = TimeType.Day
        }
        let springView = SpringView.init(timeType: self.type)
        springView.show()
    }
    
    //MARK: - UIButton Response
    @IBAction func menuButtonAction(sender: UIButton) {
        if !self.validateTimeIsDay() {
            type = TimeType.Night
        }
        else {
            type = TimeType.Day
        }
        // If SelectedItem Exist
        guard let data: NSData = UserDefault.objectForKey("SelectedItem") as? NSData else {
            let menuView = MenuView.init(timeType: type)
            menuView.delegate = self
            menuView.show({ () in
                menuView.countDownView?.animationExecute()
            })
            return
        }
        
        let indexPath = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! NSIndexPath
        let menuView = MenuView.init(timeType: type, selectedItem: indexPath)
        menuView.delegate = self
        menuView.show({ () in
            menuView.countDownView?.animationExecute()
        })
    }
    
    //MARK: - Custom Method
    func deselect(indexPath: NSIndexPath) {
        self.mainTV.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // 判断当前时间是白天还是黑夜
    func validateTimeIsDay() -> Bool {
        let currentDateString = String.getCurrentTimeString()
        if currentDateString.compare(String.getStartTimeString()) == NSComparisonResult.OrderedDescending && currentDateString.compare(String.getEndTimeString()) == NSComparisonResult.OrderedAscending {
            return true
        }
        else {
            return false
        }
    }
    
    func deleteNewsData() {
        // 获取六天前的日期 Delete News Six Days Ago 
        let deleteTimeString = String.getXDaysAgoTimeString(6)
        let newsManager = NewsHelpers.shareManager
        newsManager.deleteNews(deleteTimeString)
    }
    
    //MARK: - 模拟数据
    private lazy var cellArray: Array<NSMutableDictionary> = {
        var array = [NSMutableDictionary]()
        // NSMutableDictionary
        let plistPath = NSBundle.mainBundle().pathForResource("LocalData", ofType: ".plist")
        let plistArray = NSArray.init(contentsOfFile: plistPath!)
        for dic in plistArray! {
            let newDic = NSMutableDictionary.init(dictionary: dic as! NSDictionary)
            array.append(newDic)
        }
        return array
    }()
    /*
     *  添加plist数据到CoreData
     *  var number = 1
     *  for item in self.cellArray {
     *  let model = NewsModel()
     *  model.newsType = NSNumber.init(short: Int16(item.objectForKey("newsType") as! String)!)
     *  model.newsTitle = item.objectForKey("title") as? String
     *  model.commNum = NSNumber.init(int: Int32(item.objectForKey("commentNum") as! String)!)
     *  model.newsContent = item.objectForKey("content") as? String
     *  model.isRead = NSNumber.init(short: Int16(item.objectForKey("isRead") as! String)!)
     *  model.newsDate = "2016.07.27"
     *  model.dayOrNight = NSNumber.init(short: 0)
     *  model.newsID = "201607270\(number)"
     *  print("\(model.newsID)")
     *
     *  number += 1
     *  newsManager.addNews(model)
     *  }
     */

}

