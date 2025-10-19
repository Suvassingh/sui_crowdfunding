module move_project::coin_transfer {

    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;

    /// Transfer a specific amount of SUI to recipient.
    public fun send_sui_amount(
        mut c: Coin<SUI>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        // Split the coin into two: one with amount, rest stays with sender
        let coin_to_send = coin::split(&mut c, amount, ctx);

        // Transfer only that portion
        transfer::public_transfer(coin_to_send, recipient); # Package Id is 0x3927f12e731bb5257c21ecd94e05e43471564cb8774fdf541854b736f833a0e9

        // Transfer the leftover coin back to the sender
        transfer::public_transfer(c, tx_context::sender(ctx));
    }
}