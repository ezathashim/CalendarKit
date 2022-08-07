
import UIKit

public final class TimelineColumnTitleView: UIView {
    
    private let headerHeight: CGFloat = 24.0
    
    public var text: String = "" {
        didSet {
            self.textLabel.text = text
            self.reloadData()
        }
    }
    
    public var style: TimelineColumnTitleStyle = TimelineColumnTitleStyle() {
        didSet {
            layer.backgroundColor = style.backgroundColor.cgColor
            layer.borderColor = style.borderColor.cgColor
            layer.borderWidth = style.borderWidth
            layer.cornerRadius = style.cornerRadius
            
            textLabel.font = style.font
            textLabel.textColor = style.textColor
        }
    }
    
    public var textColor: UIColor = UIColor.black {
        didSet {
            textLabel.textColor = textColor
        }
    }
    
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = NSTextAlignment.center
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        
        label.text = text
        
        return label
    }()
    
        // MARK: - RETURN VALUES
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
        // MARK: - METHODS
    
    private func configure() {
        clipsToBounds = true
        addSubview(textLabel)
        
        let contraints = [
            
            textLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            textLabel.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            textLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            textLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ]
        
            // add padding padding
        layoutMargins = .init(top: 8, left: 8, bottom: 8, right: 8)
        
        contraints[2].priority = UILayoutPriority(995)
        contraints[3].priority = UILayoutPriority(995)
        
        addConstraints(contraints)
        NSLayoutConstraint.activate(contraints)
        
        style = TimelineColumnTitleStyle()
        
    }
    
    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelSize = textLabel.sizeThatFits(size)
        let widthValue = 1 * floor(((labelSize.width + 8 + 8)/1)+0.5);
        let heightValue = 1 * floor(((labelSize.height + 8 + 8)/1)+0.5);
        
        return CGSize(width: widthValue,
                      height: heightValue)
    }
    
    
    public func reloadData() {
        do {
            textLabel.sizeToFit()
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            let size = sizeThatFits(maxSize)
            layer.cornerRadius = size.height/4
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    
}
