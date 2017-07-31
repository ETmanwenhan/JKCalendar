//
//  JKCalendarView.swift
//  JKCalendar-Sample
//
//  Created by Joe on 2017/3/16.
//  Copyright © 2017年 Joe. All rights reserved.
//

import UIKit

class JKCalendarView: UIView{
    
    let calendar: JKCalendar
    
    var month: JKMonth{
        didSet{
            resetWeeksInfo()
            setNeedsDisplay()
        }
    }
    
    var foldValue: CGFloat = 0{
        didSet{
            updateFoldValueWeeksInfo()
            setNeedsDisplay()
        }
    }
    
    fileprivate var weeksInfo: [JKWeekInfo] = []
    fileprivate var panBeganDay: JKDay?
    fileprivate var panChangedDay: JKDay?
    
    var tapRecognizer: UITapGestureRecognizer!
    var panRecognizer: UIPanGestureRecognizer!
    
    init(calendar: JKCalendar, month: JKMonth){
        self.calendar = calendar
        self.month = month
        super.init(frame: CGRect.zero)
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        gestureRecognizers = [tapRecognizer, panRecognizer]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        resetWeeksInfo()
    }
    
    func resetWeeksInfo(){
        weeksInfo = []
        
        let firstDay = month.firstDay
        let weekday = firstDay.weekday - 1
        var offset = firstDay.previous(weekday)
        
        let calendarDaySize = CGSize(width: (bounds.width - 20) / 7,
                                     height: bounds.height / CGFloat(month.weeksCount))
        
        for weekIndex in 0 ..< month.weeksCount{
            var daysInfo: [JKDayInfo] = []
            let offsetY = weekIndex <= calendar.foldWeekIndex ?
                foldValue * CGFloat(calendar.foldWeekIndex) / CGFloat(month.weeksCount - 1):
            foldValue
            for dayIndex in 0 ..< 7{
                let dayRect = CGRect(x: 10 + CGFloat(dayIndex) * calendarDaySize.width,
                                     y: CGFloat(weekIndex) * calendarDaySize.height - offsetY,
                                     width: calendarDaySize.width,
                                     height: calendarDaySize.height)
                var info = JKDayInfo(day: offset,
                                     location: dayRect)
                if let mark = calendar.dataSource?.calendar?(calendar, markWith: info.day){
                    info.mark = mark
                }
                
                daysInfo.append(info)
                
                offset = offset.next()
            }
            weeksInfo.append(JKWeekInfo(daysInfo: daysInfo))
        }
        
        if let continuousMarks = calendar.dataSource?.calendar?(calendar, continuousMarksWith: month){
            for continuousMark in continuousMarks{
                
                for weekIndex in 0 ..< weeksInfo.count{
                    let weekDays = weeksInfo[weekIndex].days
                    if continuousMark.end < weekDays.first! || continuousMark.start > weekDays.last!{
                        continue
                    }else{
                        let lowerBound = weekDays.contains(continuousMark.start) ? weekDays.index(of: continuousMark.start)!: 0
                        let upperBound = weekDays.contains(continuousMark.end) ? weekDays.index(of: continuousMark.end)!: 6
                        let range = Range<Int>(uncheckedBounds: (lowerBound, upperBound))
                        
                        weeksInfo[weekIndex].continuousMarksInfo[continuousMark] = range
                    }
                }
            }
        }
    }
    
    func updateFoldValueWeeksInfo(){
        let calendarDaySize = CGSize(width: (bounds.width - 20) / 7,
                                     height: bounds.height / CGFloat(month.weeksCount))
        
        for weekIndex in 0 ..< weeksInfo.count{
            let offsetY = weekIndex <= calendar.foldWeekIndex ?
                foldValue * CGFloat(calendar.foldWeekIndex) / CGFloat(month.weeksCount - 1): foldValue
            
            for dayIndex in 0 ..< weeksInfo[weekIndex].daysInfo.count{
                weeksInfo[weekIndex].daysInfo[dayIndex].location =
                    CGRect(x: 10 + CGFloat(dayIndex) * calendarDaySize.width,
                           y: CGFloat(weekIndex) * calendarDaySize.height - offsetY,
                           width: calendarDaySize.width,
                           height: calendarDaySize.height)
            }
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        if weeksInfo.count == 0{
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        
        let sortWeeksInfo = weeksInfo[calendar.foldWeekIndex + 1 ..< weeksInfo.count] + weeksInfo[0 ... calendar.foldWeekIndex]
        
        for weekInfo in sortWeeksInfo{
            let firstDayInfo = weekInfo.daysInfo.first!
            let lastDayInfo = weekInfo.daysInfo.last!
            
            // Draw background
            context?.addRect(CGRect(x: firstDayInfo.location.origin.x,
                                    y: firstDayInfo.location.origin.y,
                                    width: lastDayInfo.location.origin.x + lastDayInfo.location.width - firstDayInfo.location.origin.x,
                                    height: firstDayInfo.location.height))
            context?.setFillColor(UIColor.white.cgColor)
            context?.fillPath()
            
            // Draw continuous mark
            for (mark, range) in weekInfo.continuousMarksInfo{
                
                let path = UIBezierPath()
                let beginLocation = weekInfo.daysInfo[range.lowerBound].location
                let endLocation = weekInfo.daysInfo[range.upperBound].location
                
                switch mark.type{
                    
                case .circle:
                    let height = beginLocation.height * 5 / 6
                    let radius = height / 2
                    if mark.start == mark.end{
                        let center = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                             y: beginLocation.origin.y + beginLocation.height / 2)
                        path.addArc(withCenter: center,
                                    radius: radius,
                                    startAngle: 0,
                                    endAngle: 2 * CGFloat.pi, clockwise: true)
                    }else if mark.start >= firstDayInfo.day && mark.end <= lastDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x + beginLocation.width / 2,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width / 2 - beginLocation.origin.x - beginLocation.width / 2,
                                          height: height)
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: beginLocation.origin.y + beginLocation.height / 2)
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: endLocation.origin.y + endLocation.height / 2)
                        
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: 90 * CGFloat.pi / 180,
                                    endAngle: 270 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 270 * CGFloat.pi / 180,
                                    endAngle: 90 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        
                    }else if mark.start > firstDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x + beginLocation.width / 2,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width - beginLocation.origin.x - beginLocation.width / 2,
                                          height: height)
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: beginLocation.origin.y + beginLocation.height / 2)
                        
                        path.move(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: 90 * CGFloat.pi / 180,
                                    endAngle: 270 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        
                    }else if mark.end < lastDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width / 2 - beginLocation.origin.x,
                                          height: height)
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: endLocation.origin.y + endLocation.height / 2)
                        
                        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 270 * CGFloat.pi / 180,
                                    endAngle: 90 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        
                    }else{
                        let rect = CGRect(x: beginLocation.origin.x,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width - beginLocation.origin.x,
                                          height: height)
                        
                        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                    }
                    
                    path.close()
                    context?.addPath(path.cgPath)
                    context?.setFillColor(mark.color.cgColor)
                    context?.fillPath()
                    
                case .hollowCircle:
                    let height = beginLocation.height * 5 / 6
                    let radius = height / 2
                    if mark.start == mark.end{
                        let center = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                             y: beginLocation.origin.y + beginLocation.height / 2)
                        path.addArc(withCenter: center,
                                    radius: radius,
                                    startAngle: 0,
                                    endAngle: 2 * CGFloat.pi, clockwise: true)
                    }else if mark.start >= firstDayInfo.day && mark.end <= lastDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x + beginLocation.width / 2,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width / 2 - beginLocation.origin.x - beginLocation.width / 2,
                                          height: height)
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: beginLocation.origin.y + beginLocation.height / 2)
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: endLocation.origin.y + endLocation.height / 2)
                        
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: 90 * CGFloat.pi / 180,
                                    endAngle: 270 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 270 * CGFloat.pi / 180,
                                    endAngle: 90 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        
                    }else if mark.start > firstDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x + beginLocation.width / 2,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width - beginLocation.origin.x - beginLocation.width / 2,
                                          height: height)
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: beginLocation.origin.y + beginLocation.height / 2)
                        
                        path.move(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: 90 * CGFloat.pi / 180,
                                    endAngle: 270 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        
                    }else if mark.end < lastDayInfo.day{
                        let rect = CGRect(x: beginLocation.origin.x,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width / 2 - beginLocation.origin.x,
                                          height: height)
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: endLocation.origin.y + endLocation.height / 2)
                        
                        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 270 * CGFloat.pi / 180,
                                    endAngle: 90 * CGFloat.pi / 180,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        
                    }else{
                        let rect = CGRect(x: beginLocation.origin.x,
                                          y: beginLocation.origin.y + (beginLocation.height - height) / 2,
                                          width: endLocation.origin.x + endLocation.width - beginLocation.origin.x,
                                          height: height)
                        
                        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
                        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
                        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
                    }
                    
                    context?.addPath(path.cgPath)
                    context?.setLineWidth(1)
                    context?.setStrokeColor(mark.color.cgColor)
                    context?.strokePath()
                    
                case .underline:
                    let offsetY = beginLocation.origin.y + beginLocation.height - 2
                    let lineWidth = beginLocation.height * 3 / 4
                    if mark.start == mark.end{
                        let beginX = beginLocation.origin.x + (beginLocation.width - lineWidth) / 2
                        let endX = beginX + lineWidth
                        path.move(to: CGPoint(x: beginX, y: offsetY))
                        path.addLine(to: CGPoint(x: endX, y: offsetY))
                        
                    }else if mark.start >= firstDayInfo.day && mark.end <= lastDayInfo.day{
                        let beginX = beginLocation.origin.x + (beginLocation.width - lineWidth) / 2
                        let endX = endLocation.origin.x + (endLocation.width - lineWidth) / 2 + lineWidth
                        path.move(to: CGPoint(x: beginX, y: offsetY))
                        path.addLine(to: CGPoint(x: endX, y: offsetY))
                        
                    }else if mark.start > firstDayInfo.day{
                        let beginX = beginLocation.origin.x + (beginLocation.width - lineWidth) / 2
                        let endX = endLocation.origin.x + endLocation.width
                        path.move(to: CGPoint(x: beginX, y: offsetY))
                        path.addLine(to: CGPoint(x: endX, y: offsetY))
                        
                    }else if mark.end < lastDayInfo.day{
                        let beginX = beginLocation.origin.x
                        let endX = endLocation.origin.x + (endLocation.width - lineWidth) / 2 + lineWidth
                        path.move(to: CGPoint(x: beginX, y: offsetY))
                        path.addLine(to: CGPoint(x: endX, y: offsetY))
                        
                    }else{
                        let beginX = beginLocation.origin.x
                        let endX = endLocation.origin.x + endLocation.width
                        path.move(to: CGPoint(x: beginX, y: offsetY))
                        path.addLine(to: CGPoint(x: endX, y: offsetY))
                        
                    }
                    
                    context?.addPath(path.cgPath)
                    context?.setLineWidth(2)
                    context?.setStrokeColor(mark.color.cgColor)
                    context?.strokePath()
                    
                case .dot:
                    let offsetY = beginLocation.origin.y + beginLocation.height - 2
                    let radius: CGFloat = 2
                    if mark.start == mark.end{
                        let center = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                             y: offsetY)
                        path.addArc(withCenter: center,
                                    radius: radius,
                                    startAngle: CGFloat.pi,
                                    endAngle: 3 * CGFloat.pi,
                                    clockwise: true)
                        
                    }else if mark.start >= firstDayInfo.day && mark.end <= lastDayInfo.day{
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: offsetY)
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: offsetY)
                        
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: CGFloat.pi,
                                    endAngle: 3 * CGFloat.pi,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rightCenter.x - 2, y: rightCenter.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 0,
                                    endAngle: 2 * CGFloat.pi,
                                    clockwise: true)
                        
                    }else if mark.start > firstDayInfo.day{
                        let leftCenter = CGPoint(x: beginLocation.origin.x + beginLocation.width / 2,
                                                 y: offsetY)
                        
                        path.addArc(withCenter: leftCenter,
                                    radius: radius,
                                    startAngle: CGFloat.pi,
                                    endAngle: 3 * CGFloat.pi,
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: endLocation.origin.x + endLocation.width, y: offsetY))
                        
                    }else if mark.end < lastDayInfo.day{
                        let rightCenter = CGPoint(x: endLocation.origin.x + endLocation.width / 2,
                                                  y: offsetY)
                        
                        path.move(to: CGPoint(x: beginLocation.origin.x, y: offsetY))
                        path.addLine(to: CGPoint(x: rightCenter.x - 2, y: rightCenter.y))
                        path.addArc(withCenter: rightCenter,
                                    radius: radius,
                                    startAngle: 0,
                                    endAngle: 2 * CGFloat.pi,
                                    clockwise: true)
                    }else{
                        path.move(to: CGPoint(x: beginLocation.origin.x, y: offsetY))
                        path.addLine(to: CGPoint(x: endLocation.origin.x + endLocation.width, y: offsetY))
                    }
                    
                    context?.addPath(path.cgPath)
                    context?.setLineWidth(1)
                    context?.setStrokeColor(mark.color.cgColor)
                    context?.strokePath()
                    
                    context?.addPath(path.cgPath)
                    context?.setFillColor(mark.color.cgColor)
                    context?.fillPath()
                }
            }
            
            // Draw mark
            for info in weekInfo.daysInfo{
                if let mark = info.mark{
                    switch mark.type{
                    case .circle:
                        context?.setFillColor(mark.color.withAlphaComponent(alpha).cgColor)
                        let diameter = info.location.height * 5 / 6
                        let rect = CGRect(x: info.location.origin.x + (info.location.width - diameter) / 2,
                                          y: info.location.origin.y + (info.location.height - diameter) / 2,
                                          width: diameter,
                                          height: diameter)
                        context?.addEllipse(in: rect)
                        context?.fillPath()
                    case .hollowCircle:
                        context?.setLineWidth(1)
                        context?.setStrokeColor(mark.color.withAlphaComponent(alpha).cgColor)
                        let diameter = info.location.height * 5 / 6
                        let rect = CGRect(x: info.location.origin.x + (info.location.width - diameter) / 2,
                                          y: info.location.origin.y + (info.location.height - diameter) / 2,
                                          width: diameter,
                                          height: diameter)
                        context?.addEllipse(in: rect)
                        context?.strokePath()
                    case .underline:
                        context?.setLineWidth(2)
                        context?.setStrokeColor(mark.color.withAlphaComponent(alpha).cgColor)
                        let width = info.location.height * 3 / 4
                        let offsetY = info.location.height - 2
                        let startPoint = CGPoint(x: info.location.origin.x + (info.location.width - width) / 2,
                                                 y: info.location.origin.y + offsetY)
                        let endPoint = CGPoint(x: info.location.origin.x + (info.location.width - width) / 2 + width,
                                               y: info.location.origin.y + offsetY)
                        context?.addLines(between: [startPoint, endPoint])
                        context?.strokePath()
                    case .dot:
                        let context = UIGraphicsGetCurrentContext()
                        context?.setFillColor(mark.color.withAlphaComponent(alpha).cgColor)
                        let diameter: CGFloat = 4
                        let offsetY = info.location.height - 4
                        let rect = CGRect(x: info.location.origin.x + (info.location.width - diameter) / 2,
                                          y: info.location.origin.y + offsetY,
                                          width: diameter,
                                          height: diameter)
                        context?.addEllipse(in: rect)
                        context?.fillPath()
                    }
                }
            }
            
            // Draw Text
            for info in weekInfo.daysInfo{
                let dayString = "\(info.day.day)" as NSString
                let font = UIFont(name: "HelveticaNeue-Medium", size: 13)!
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                var unitStrAttrs = [NSFontAttributeName: font,
                                    NSParagraphStyleAttributeName: paragraphStyle]
                
                if let mark = info.mark, mark.type == .circle{
                    unitStrAttrs[NSForegroundColorAttributeName] = calendar.backgroundColor
                }else if weekInfo.continuousMarksInfo.keys.filter({ (mark) -> Bool in
                    return mark.type == .circle
                }).contains(where: { (mark) -> Bool in
                    return info.day >= mark.start && info.day <= mark.end
                }){
                    unitStrAttrs[NSForegroundColorAttributeName] = calendar.backgroundColor
                }else if info.day == month{
                    unitStrAttrs[NSForegroundColorAttributeName] = calendar.textColor
                }else{
                    unitStrAttrs[NSForegroundColorAttributeName] = calendar.textColor.withAlphaComponent(0.3)
                }
                
                let textSize = dayString.size(attributes: [NSFontAttributeName: font])
                let dy = (info.location.height - textSize.height) / 2
                
                let textRect = CGRect(x: info.location.origin.x,
                                      y: info.location.origin.y + dy,
                                      width: info.location.width,
                                      height: textSize.height)
                dayString.draw(in: textRect, withAttributes: unitStrAttrs)
            }
        }
    }
    
    fileprivate func dayInfo(tapPosition: CGPoint) -> JKDayInfo?{
        for weekInfo in weeksInfo{
            for info in weekInfo.daysInfo{
                if tapPosition.x > info.location.origin.x &&
                    tapPosition.x < info.location.origin.x + info.location.width &&
                    tapPosition.y > info.location.origin.y &&
                    tapPosition.y < info.location.origin.y + info.location.height{
                    return info
                }
            }
        }
        
        return nil
    }
    
    func handleTap(_ recognizer: UITapGestureRecognizer){
        let position = recognizer.location(in: self)
        if let info = dayInfo(tapPosition: position){
            calendar.delegate?.calendar?(calendar, didTouch: info.day)
        }
    }
    
    func handlePan(_ recognizer: UIPanGestureRecognizer){
        let position = recognizer.location(in: self)
        if let info = dayInfo(tapPosition: position){
            switch recognizer.state {
            case .began:
                calendar.delegate?.calendar?(calendar, didPan: [info.day])
                panBeganDay = info.day
                panChangedDay = info.day
            case .changed:
                if let changedDay = panChangedDay, changedDay == info.day{
                }else if let beganDay = panBeganDay{
                    calendar.delegate?.calendar?(calendar, didPan: beganDay.days(until: info.day))
                }
                panChangedDay = info.day
            case .ended:
                panBeganDay = nil
                panChangedDay = nil
            default:
                break
            }
        }
    }
    
    struct JKWeekInfo {
        var days: [JKDay]{
            return daysInfo.map({ (info) -> JKDay in
                return info.day
            })
        }
        var daysInfo: [JKDayInfo]
        var continuousMarksInfo: [JKCalendarContinuousMark: Range<Int>] = [:]
        
        init(daysInfo: [JKDayInfo]){
            self.daysInfo = daysInfo
        }
    }
    
    struct JKDayInfo {
        let day: JKDay
        var location: CGRect
        
        var mark: JKCalendarMark?
//        var continuousMarks: [JKCalendarContinuousMark]?
        
        init(day: JKDay, location: CGRect){
            self.day = day
            self.location = location
        }
        
    }
    
    class JKCalendarWeekView: UIView{
        
    }
    
}
