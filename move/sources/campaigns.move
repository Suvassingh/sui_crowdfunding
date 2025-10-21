





module 0x0::crowdfunding {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::event;

    // --- Campaign object ---
    public struct Campaign has key, store {
        id: UID,
        title: vector<u8>,
        description: vector<u8>,
        creator: address,
        goal: u64,
        raised: u64,
        start_time: u64,
        end_time: u64,
        active: bool,
        image_url: vector<u8>,
        balance: Balance<SUI>
    }

    // --- Admin capability object ---
    public struct CampaignAdminCap has key {
        id: UID,
    }

    // --- Contribution Receipt ---
    public struct ContributionReceipt has key, store {
        id: UID,
        campaign_id: ID,
        contributor: address,
        amount: u64,
        timestamp: u64,
    }

    // --- Events ---
    public struct CampaignCreated has copy, drop {
        campaign_id: ID,
        creator: address,
        goal: u64,
        end_time: u64
    }

    public struct CampaignContributed has copy, drop {
        campaign_id: ID,
        contributor: address,
        amount: u64
    }

    // --- Errors ---
    const ENotAdmin: u64 = 0;
    const ECampaignEnded: u64 = 1;
    const EGoalNotReached: u64 = 2;
    const EInsufficientContribution: u64 = 3;
    const ENotCreator: u64 = 4;
    const ECampaignStillActive: u64 = 5;
    const EWithdrawalNotAllowed: u64 = 6;
    const ENoFundsToWithdraw: u64 = 7;

    // --- init (called at module publish) ---
    fun init(ctx: &mut TxContext) {
        let admin_cap = CampaignAdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // --- Create campaign ---
    public entry fun create_campaign(
        _admin_cap: &CampaignAdminCap,
        title: vector<u8>,
        description: vector<u8>,
        goal: u64,
        duration_days: u64,
        image_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(goal > 0, EInsufficientContribution);

        let campaign = Campaign {
            id: object::new(ctx),
            title,
            description,
            creator: tx_context::sender(ctx),
            goal,
            raised: 0,
            start_time: tx_context::epoch(ctx),
            end_time: tx_context::epoch(ctx) + duration_days * 24 * 60 * 60,
            active: true,
            image_url,
            balance: balance::zero<SUI>()
        };

        // Emit event
        event::emit(CampaignCreated {
            campaign_id: object::id(&campaign),
            creator: campaign.creator,
            goal: campaign.goal,
            end_time: campaign.end_time
        });

        transfer::share_object(campaign);
    }

    // --- Contribute to campaign ---
    public entry fun contribute(
        campaign: &mut Campaign,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(campaign.active, ECampaignEnded);
        assert!(tx_context::epoch(ctx) <= campaign.end_time, ECampaignEnded);
        
        let amount = coin::value(&payment);
        assert!(amount > 0, EInsufficientContribution);

        // Update campaign state
        campaign.raised = campaign.raised + amount;
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut campaign.balance, payment_balance);

        // Create contribution receipt
        let receipt = ContributionReceipt {
            id: object::new(ctx),
            campaign_id: object::id(campaign),
            contributor: tx_context::sender(ctx),
            amount,
            timestamp: tx_context::epoch(ctx),
        };

        // Emit event
        event::emit(CampaignContributed {
            campaign_id: object::id(campaign),
            contributor: tx_context::sender(ctx),
            amount: amount
        });

        // Transfer receipt to contributor
        transfer::transfer(receipt, tx_context::sender(ctx));

        // Check if goal reached and deactivate campaign
        if (campaign.raised >= campaign.goal) {
            campaign.active = false;
        }
    }

    // --- Withdraw funds (creator only) ---
    public entry fun withdraw_funds(
        campaign: &mut Campaign,
        ctx: &mut TxContext
    ) {
        assert!(campaign.creator == tx_context::sender(ctx), ENotCreator);
        assert!(!campaign.active, ECampaignStillActive);
        assert!(campaign.raised >= campaign.goal, EGoalNotReached);
        
        let balance_value = balance::value(&campaign.balance);
        assert!(balance_value > 0, ENoFundsToWithdraw);

        // Take the entire balance
        let balance_to_convert = balance::split(&mut campaign.balance, balance_value);
        let funds_coin = coin::from_balance(balance_to_convert, ctx);
        
        // Transfer to creator
        transfer::public_transfer(funds_coin, campaign.creator);

        // Reset raised amount
        campaign.raised = 0;
    }

    // --- Refund contributors if campaign fails ---
    public entry fun refund_contributors(
        campaign: &mut Campaign,
        ctx: &mut TxContext
    ) {
        let current_time = tx_context::epoch(ctx);
        assert!(current_time > campaign.end_time, ECampaignStillActive);
        assert!(campaign.raised < campaign.goal, EWithdrawalNotAllowed);
        assert!(balance::value(&campaign.balance) > 0, ENoFundsToWithdraw);

        // For simplicity, we just deactivate the campaign
        // In a full implementation, you'd refund individual contributors
        campaign.active = false;
    }

    // --- Emergency cancel (admin only) ---
    public entry fun emergency_cancel(
        _admin_cap: &CampaignAdminCap,
        campaign: &mut Campaign,
        _ctx: &mut TxContext
    ) {
        campaign.active = false;
    }

    // --- Read-only helpers ---
    public fun get_campaign_info(campaign: &Campaign): (
        address,
        vector<u8>,
        vector<u8>,
        u64,
        u64,
        bool,
        u64,
        u64,
        vector<u8>
    ) {
        (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.active,
            campaign.start_time,
            campaign.end_time,
            campaign.image_url
        )
    }

    public fun is_active(campaign: &Campaign): bool {
        campaign.active
    }

    public fun get_raised_amount(campaign: &Campaign): u64 {
        campaign.raised
    }

    public fun get_goal_amount(campaign: &Campaign): u64 {
        campaign.goal
    }

    public fun get_end_time(campaign: &Campaign): u64 {
        campaign.end_time
    }

    public fun get_creator(campaign: &Campaign): address {
        campaign.creator
    }

    public fun get_balance_value(campaign: &Campaign): u64 {
        balance::value(&campaign.balance)
    }
}




