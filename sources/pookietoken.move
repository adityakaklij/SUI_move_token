

module pookietoken::pookietoken;

// A OTW is special type such that it impose a funciton to be called only once, just kind of constructor function 
// It's a struct with same name of package

// use sui::coin;
use sui::url;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::sui::SUI;

const ETotalSupplyReached:u64 = 501;
const E_InsufficientPayment:u64 = 502;


const TOTAL_SUPPLY:u64 = 1_000_000_000_000000; // 1 Billion with _6 decimal
const INITIAL_MINT:u64 = 1_00_000_000000; // 1 Million initial mint
const MINT_PRICE:u256 = 1_0_000_000; // 0.01 SUI @note not working

public struct POOKIETOKEN has drop {}

public struct OwnerOnly has key {
    id: UID,
}

public struct MintCapability has key, store {
    id: UID,
    total_minted:u64
}
#[allow(deprecated_usage)]
fun init(witness: POOKIETOKEN, ctx: &mut TxContext) {
    let (mut treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"POOKIE", 
        b"POOKIE",
        b"POOKIE",
        option::some(url::new_unsafe_from_bytes(b"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR7_VUHdOZ8ZBrCfoUoIhpmBMI3mXKPf50ifA&s")),
        ctx,
        );

        let mut mint_cap = MintCapability { 
            id:object::new(ctx), 
            total_minted:INITIAL_MINT 
        };

        mint_internal(&mut treasury, INITIAL_MINT,ctx.sender(), &mut mint_cap, ctx);
        let owner = OwnerOnly { id:object::new(ctx) };
        transfer::transfer(owner, ctx.sender());
        transfer::public_transfer(mint_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
}


fun mint_internal(treasure_cap: &mut TreasuryCap<POOKIETOKEN>, amount:u64, recipient:address, cap:&mut MintCapability, ctx: &mut TxContext){
    // Check total supply before mint
    assert!( cap.total_minted + amount <= TOTAL_SUPPLY, ETotalSupplyReached);
    let coin = coin::mint(treasure_cap,amount, ctx);
    
    transfer::public_transfer(coin, recipient);
    cap.total_minted = cap.total_minted + amount;
}

// Mint Owner only
public fun mint(_:&OwnerOnly, treasure_cap: &mut TreasuryCap<POOKIETOKEN>, amount:u64, recipient:address, cap:&mut MintCapability, ctx: &mut TxContext){
    mint_internal(treasure_cap, amount, recipient, cap, ctx);
}

// Mint Owner only
// This function is uesless will not work!
public fun pay_n_mint( self:&mut Coin<SUI>, treasure_cap: &mut TreasuryCap<POOKIETOKEN>, amount:u64, recipient:address, cap:&mut MintCapability, ctx: &mut TxContext){
    
    // Accept SUI token to ming
    // 1 POOKI = 0.01 SUI
    assert!(amount as u256 >= MINT_PRICE, E_InsufficientPayment);
    let payment = coin::split(self, amount, ctx);
    transfer::public_transfer(payment, @0x1c907d948e6c62d699735b5b655792429fb57680e3082b007c79010cd692f385);
    mint_internal(treasure_cap, amount, recipient, cap, ctx);
}


#[test_only]
use sui::test_scenario;
use std::unit_test::assert_eq;

#[test]
fun test_mint() {

    let address01 = @0xA1;

    // Deploy the contract
    let mut scenario = test_scenario::begin(address01);{
        let otw = POOKIETOKEN{};
        init(otw, scenario.ctx());
    };

    // Check the initial mint of tokens
    scenario.next_tx(address01);{
        let pookie_coin = scenario.take_from_sender<coin::Coin<POOKIETOKEN>>();

        assert_eq!(pookie_coin.balance().value() , INITIAL_MINT );
        scenario.return_to_sender(pookie_coin);

        
    };

    // Mint 2_00 tokens and check the if user balance is increase or not ALSO, check total_minted as well
    scenario.next_tx(address01);{

        let ownerOnly = scenario.take_from_sender<OwnerOnly>();
        let mut treasure = scenario.take_from_address<TreasuryCap<POOKIETOKEN>>(address01); // @note Keep this in consideration that we are using take_from_address here.
        let mut mintCap = scenario.take_from_sender<MintCapability>();

        mint(&ownerOnly, &mut treasure, 200_000_000, address01, &mut mintCap,  scenario.ctx());

        scenario.return_to_sender(ownerOnly);
        scenario.return_to_sender(mintCap);
        scenario.return_to_sender(treasure);

    };
    scenario.next_tx(address01);{

        let pookie_coin1 = scenario.take_from_sender<coin::Coin<POOKIETOKEN>>();
        let pookie_coin2 = scenario.take_from_sender<coin::Coin<POOKIETOKEN>>();
        
        // We have to take 2 balance, 1 in from initial mint another from later mint
        let bal1 = pookie_coin1.balance().value();
        let bal2  = pookie_coin2.balance().value();

        assert_eq!(bal1 + bal2,   INITIAL_MINT + 200_000_000);
        scenario.return_to_sender(pookie_coin1);
        scenario.return_to_sender(pookie_coin2);

    };
    scenario.end();


}
// Test will fail to check minting the tokne from address 02
#[test]
#[expected_failure]
fun test_mint_non_owner() {
    let address01 = @0xA1;
    let address02 = @0xB1;

    let mut scenario = test_scenario::begin(address01);{
        let otw = POOKIETOKEN{};
        init(otw, scenario.ctx());
    };

    scenario.next_tx(address02);{
        let ownerOnly = scenario.take_from_sender<OwnerOnly>();
        let mut treasure = scenario.take_from_address<TreasuryCap<POOKIETOKEN>>(address01); // @note Keep this in consideration that we are using take_from_address here.
        let mut mintCap = scenario.take_from_sender<MintCapability>();

        mint(&ownerOnly, &mut treasure, INITIAL_MINT + 200_000_000, address01, &mut mintCap,  scenario.ctx());

        scenario.return_to_sender(ownerOnly);
        scenario.return_to_sender(mintCap);
        scenario.return_to_sender(treasure);
    };

    scenario.end();
}

// Minting function with non owner address paying SUI
// #[test]
// fun test_pay_sui_n_mint_non_owner() {
//     let address01 = @0xA1;
//     let address02 = @0xB1;

//     let mut scenario = test_scenario::begin(address01);{
//         let otw = POOKIETOKEN{};
//         init(otw, scenario.ctx());
//     };

//     scenario.next_tx(address02);{
   
//         let mut treasure = scenario.take_from_address<TreasuryCap<POOKIETOKEN>>(address02); // @note Keep this in consideration that we are using take_from_address here.
//         let mut mintCap = scenario.take_from_sender<MintCapability>();
//         let mut sui_coin = scenario.take_from_sender<Coin<SUI>>();

//         pay_n_mint( &mut sui_coin,&mut treasure,  300_000_000, address02, &mut mintCap,  scenario.ctx());


//         scenario.return_to_sender(mintCap);
//         scenario.return_to_sender(treasure);
//         scenario.return_to_sender(sui_coin);
//     };

//     scenario.end();
// }