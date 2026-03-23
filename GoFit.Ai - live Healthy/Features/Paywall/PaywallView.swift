import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedPlan: PlanType = .monthly
    @State private var loading = false
    @State private var error: String?
    @State private var animateFeatures = false
    @State private var isBlocking = false // True when trial expired and blocking access
    
    enum PlanType {
        case monthly
        case yearly
        
        var id: String {
            switch self {
            case .monthly: return "com.gofitai.premium.monthlyy"
            case .yearly: return "com.gofitai.premium.yearlyyy"
            }
        }
        
        var periodText: String {
            switch self {
            case .monthly: return "month"
            case .yearly: return "year"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background for dark mode
                Design.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {
                        header
                        features
                        plans
                        boostPackSection
                        ctaButton
                        skipWithAdsButton
                        terms
                    }
                    .padding(.bottom, Design.Spacing.xl)
                    .frame(maxWidth: 600) // Limit width on iPad for better layout
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Always show close button - users can use free tier with ads
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { 
                        dismiss() 
                    }
                    .foregroundColor(Design.Colors.primary)
                }
            }
            .onAppear {
                // Load products when paywall appears
                purchases.loadProducts()
                
                // isBlocking is no longer used since app is free with ads
                isBlocking = false
                
                // Animate features
                withAnimation(.spring().delay(0.1)) {
                    animateFeatures = true
                }
            }
            .onChange(of: purchases.requiresSubscription) { oldValue, newValue in
                isBlocking = newValue
            }
            .onChange(of: purchases.hasActiveSubscription) { oldValue, newValue in
                // When subscription becomes active, only dismiss if this was a blocking paywall
                // For non-blocking paywalls (after signup), let user dismiss manually
                if newValue && isBlocking {
                    // If this was a blocking paywall and subscription is now active, dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var boostPackSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading) {
                    Text("Boost Pack (7 days)")
                        .font(Design.Typography.headline)
                    Text("One-time purchase for 7 days of premium coaching + double points")
                        .font(Design.Typography.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            Button {
                Task {
                    await purchaseBoostPack()
                }
            } label: {
                HStack {
                    Text("Buy Boost Pack")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    if purchases.boostPackCount > 0 {
                        Text("x\(purchases.boostPackCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Design.Colors.primaryGradient)
                .cornerRadius(14)
            }
            .disabled(purchases.isLoading || loading)
            .opacity(purchases.isLoading || loading ? 0.6 : 1)
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius( 16 )
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: Design.Scale.value(40, textStyle: .title2)))
                .foregroundColor(.white)
                .padding()
                .background(Design.Colors.primaryGradient)
                .clipShape(Circle())

            Text("Upgrade to Premium")
                .font(Design.Typography.largeTitle)

            VStack(spacing: 8) {
                Text("Unlock All Features")
                    .font(Design.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Design.Colors.primary)
                
                Text("Remove ads and get unlimited access to all premium features")
                    .font(Design.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top)
    }

    // MARK: - Features
    private var features: some View {
        VStack(spacing: 12) {
            FeatureRow(icon: "camera.fill", title: "Unlimited AI Scans", description: "No daily limits", delay: 0.1)
            FeatureRow(icon: "sparkles", title: "Smart AI Coach", description: "Personalized recommendations", delay: 0.2)
            FeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed progress insights", delay: 0.3)
            FeatureRow(icon: "rectangle.slash", title: "Ad-Free Experience", description: "Zero interruptions", delay: 0.4)
            FeatureRow(icon: "applewatch", title: "Apple Watch Sync", description: "Full HealthKit integration", delay: 0.5)
        }
        .opacity(animateFeatures ? 1 : 0)
    }

    // MARK: - Plans
    private var plans: some View {
        VStack(spacing: 16) {
            if purchases.isLoading {
                ProgressView("Loading plans…")
                    .padding()
                    .foregroundColor(.white)
            } else if purchases.products.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Products not available")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Please check your internet connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                let relevantProducts = purchases.products
                    .filter { $0.id == PlanType.monthly.id || $0.id == PlanType.yearly.id }
                    .sorted { lhs, rhs in
                        // Prefer showing Yearly first (best value), then Monthly
                        if lhs.id == PlanType.yearly.id { return true }
                        if rhs.id == PlanType.yearly.id { return false }
                        return lhs.id < rhs.id
                    }

                if relevantProducts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Products not available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Please check your App Store Connect products or StoreKit configuration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                // Show both monthly and yearly plans with subscription details
                ForEach(relevantProducts, id: \.id) { product in
                    let planType: PlanType = product.id == PlanType.monthly.id ? .monthly : .yearly
                    let isSelected = selectedPlan == planType
                    
                    VStack(spacing: Design.Spacing.sm) {
                        PlanCard(
                            product: product,
                            type: planType,
                            isSelected: isSelected
                        ) {
                            withAnimation(.spring()) {
                                selectedPlan = planType
                            }
                        }
                        
                        // Display subscription details for selected plan (Apple requirement)
                        if isSelected {
                            subscriptionDetailsView(product: product, planType: planType)
                        }
                    }
                }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - CTA
    private func purchaseBoostPack() async {
        guard let product = purchases.getProduct(id: PurchaseManager.shared?.boostPackID ?? "") else {
            error = "Boost product unavailable right now"
            return
        }

        loading = true
        do {
            try await purchases.purchase(productId: product.id)
            error = nil
            NotificationService.shared.sendNowNotification(
                title: "Boost Activated!",
                body: "Enjoy 7 days of premium features and bonus rewards"
            )
        } catch let purchaseError {
            error = purchaseError.localizedDescription
        }
        loading = false
    }

    private var ctaButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    if loading {
                        ProgressView().tint(.white)
                    } else {
                        VStack(spacing: 4) {
                            Text("Subscribe Now")
                                .font(Design.Typography.headline)
                            if let product = purchases.getProduct(id: selectedPlan.id) {
                                Text("\(product.displayPrice)/\(selectedPlan.periodText)")
                                    .font(Design.Typography.caption2)
                                    .opacity(0.9)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Design.Colors.primaryGradient)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(loading || purchases.isLoading || purchases.products.isEmpty)

            if let error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    private var skipWithAdsButton: some View {
        Button {
            dismiss()
        } label: {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                    Text("Continue with Free Version")
                        .fontWeight(.medium)
                }
                Text("Limited features • Includes ads")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Design.Colors.cardBackground)
            .foregroundColor(.primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Terms & Subscription Info
    private var terms: some View {
        VStack(spacing: Design.Spacing.md) {
            // Required Subscription Information (Apple Guidelines 3.1.2)
            if let product = purchases.getProduct(id: selectedPlan.id) {
                VStack(spacing: Design.Spacing.sm) {
                    // Subscription Title
                    Text("GoFit.Ai Premium")
                        .font(Design.Typography.headline)
                        .foregroundColor(.primary)
                    
                    // Subscription Length
                    Text("Auto-renewable subscription")
                        .font(Design.Typography.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Subscription Period
                    Text("\(selectedPlan.periodText.capitalized) subscription")
                        .font(Design.Typography.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Price Information
                    VStack(spacing: 4) {
                        Text("\(product.displayPrice)/\(selectedPlan.periodText)")
                            .font(Design.Typography.headline)
                            .foregroundColor(.primary)
                        
                        // Price per unit if applicable
                        if selectedPlan == .yearly {
                            Group {
                                if let monthlyPriceString = formatMonthlyPrice(from: product.price) {
                                    Text("\(monthlyPriceString) per month")
                                        .font(Design.Typography.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Design.Spacing.sm)
                    
                    Text("Cancel anytime in Settings")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(Design.Spacing.md)
                .background(Design.Colors.cardBackground)
                .cornerRadius(Design.Radius.medium)
            }
            
            // Required Links (Apple Guidelines 3.1.2)
            VStack(spacing: Design.Spacing.sm) {
                // Terms of Use (EULA) Link - Must be functional
                if let termsURL = URL(string: "https://github.com/RAKSHIT1998/GoFit.Ai---live-Healthy-main/blob/main/docs/TERMS_AND_CONDITIONS.md") {
                    Link(destination: termsURL) {
                        HStack(spacing: 4) {
                            Text("Terms of Use")
                                .font(Design.Typography.caption)
                                .foregroundColor(Design.Colors.primary)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundColor(Design.Colors.primary)
                        }
                    }
                } else {
                    // Fallback if URL is invalid
                    Text("Terms of Use")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/RAKSHIT1998/GoFit.Ai---live-Healthy-main/blob/main/docs/TERMS_AND_CONDITIONS.md") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                
                // Privacy Policy Link - Must be functional
                if let privacyURL = URL(string: "https://github.com/RAKSHIT1998/GoFit.Ai---live-Healthy-main/blob/main/docs/PRIVACY_POLICY.md") {
                    Link(destination: privacyURL) {
                        HStack(spacing: 4) {
                            Text("Privacy Policy")
                                .font(Design.Typography.caption)
                                .foregroundColor(Design.Colors.primary)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundColor(Design.Colors.primary)
                        }
                    }
                } else {
                    // Fallback if URL is invalid
                    Text("Privacy Policy")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/RAKSHIT1998/GoFit.Ai---live-Healthy-main/blob/main/docs/PRIVACY_POLICY.md") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
            }
            .padding(.vertical, Design.Spacing.sm)
            
            // Restore Purchases
            Button("Restore Purchases") {
                Task { 
                    do {
                        try await purchases.restorePurchases()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .font(Design.Typography.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, Design.Spacing.md)
        .padding(.top, Design.Spacing.sm)
    }

    // MARK: - Helper Functions
    private func formatMonthlyPrice(from yearlyPrice: Decimal) -> String? {
        let monthlyPrice = yearlyPrice / 12.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSDecimalNumber(decimal: monthlyPrice))
    }
    
    // MARK: - Subscription Details (Required by Apple)
    private func subscriptionDetailsView(product: Product, planType: PlanType) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            // Title
            Text("Subscription Details")
                .font(Design.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Subscription length
            HStack {
                Text("Length:")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
                Text("\(planType.periodText.capitalized)")
                    .font(Design.Typography.caption)
                    .foregroundColor(.primary)
            }
            
            // Price
            HStack {
                Text("Price:")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
                Text("\(product.displayPrice) per \(planType.periodText)")
                    .font(Design.Typography.caption)
                    .foregroundColor(.primary)
            }
            
            // Price per unit (for yearly)
            if planType == .yearly {
                Group {
                    if let monthlyPriceString = formatMonthlyPrice(from: product.price) {
                        HStack {
                            Text("Price per month:")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                            Text(monthlyPriceString)
                                .font(Design.Typography.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.Spacing.sm)
        .background(Design.Colors.secondaryBackground)
        .cornerRadius(Design.Radius.small)
    }
    
    private func purchase() async {
        loading = true
        error = nil

        do {
            try await purchases.purchase(productId: selectedPlan.id)
            // Purchase successful - update subscription status (non-blocking)
            Task {
                await purchases.checkTrialAndSubscriptionStatus()
            }
            
            await MainActor.run {
                loading = false
                // Dismiss paywall immediately after successful purchase
                dismiss()
            }
        } catch let purchaseError {
            await MainActor.run {
                loading = false
                if let purchaseError = purchaseError as? PurchaseError {
                    switch purchaseError {
                    case .userCancelled:
                        // Don't show error for user cancellation
                        break
                    default:
                        self.error = purchaseError.localizedDescription
                    }
                } else {
                    self.error = purchaseError.localizedDescription
                }
            }
        }
    }
}
