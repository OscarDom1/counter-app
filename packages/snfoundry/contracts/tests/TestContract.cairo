
use contracts::counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::EventSpyAssertionsTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn OSCAR() -> ContractAddress {
    'OSCAR'.try_into().unwrap()
}

fn __deploy__() -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {

    let contract_class = declare("Counter").expect('failed to declare').contract_class();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    let counter = ICounterDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ICounterSafeDispatcher { contract_address };
    (counter, ownable, safe_dispatcher)
}

#[test]
fn test_counter_deployment() {
    let (counter, ownable, _) = __deploy__();

    let count_1 = counter.get_counter();

    assert(count_1 == 0, 'count should be 0');
    assert(ownable.owner() == OWNER(), 'owner not set');
}

#[test]
fn test_increase_counter() {
    let (counter, _, _) = __deploy__();

    let count_1 = counter.get_counter();
    assert(count_1 == 0, 'count not set');
    counter.increase_counter();

    let count_2 = counter.get_counter();

    assert(count_2 == count_1 + 1, 'invalid count');
}

#[test]
fn test_emitted_increased_event() {
    let (counter, _, _) = __deploy__();

    let mut spy = spy_events();
    start_cheat_caller_address(counter.contract_address, OSCAR());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy.assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Increased(Counter::Increased { account: OSCAR() }),
            ),
        ],
    );
    spy.assert_not_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Decreased(Counter::Decreased { account: OSCAR() }),
            ),
        ],
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    let (counter, _, safe_dispatcher) = __deploy__();
    assert(counter.get_counter() == 0, 'invalid count');

    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("cannot decrease 0"),
        Result::Err(e) => assert(*e[0] == 'Decreasing Empty counter', *e.at(0)),
    };
}

#[test]
#[should_panic(expected: ('Decreasing Empty counter',))]
fn test_panic_decrease_counter() {
    let (counter, _, _) = __deploy__();

    assert(counter.get_counter() == 0, 'invalid count');
    counter.decrease_counter();
}

#[test]
fn test_successful_decrease_counter() {
    let (counter, _, _) = __deploy__();

    counter.increase_counter(); 
    counter.increase_counter(); 
    counter.increase_counter(); 
    counter.increase_counter();
    counter.increase_counter();

    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid count setup');

    counter.decrease_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 - 1, 'invalid decrease count');
}

#[test]
fn test_emitted_decresed_event() {
    let (counter, _, _) = __deploy__();

    counter.increase_counter();
    counter.increase_counter();
    counter.increase_counter();
    counter.increase_counter(); 
    counter.increase_counter();
    assert(counter.get_counter() == 5, 'invalid count setup');

    let mut spy = spy_events();
    start_cheat_caller_address(counter.contract_address, OSCAR());
    counter.decrease_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy.assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Decreased(Counter::Decreased { account: OSCAR() }),
            ),
        ],
    );
    spy.assert_not_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Increased(Counter::Increased { account: OSCAR() }),
            ),
        ],
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_reset_counter_by_non_owner() {
    let (counter, _, safe_dispatcher) = __deploy__();
    assert(counter.get_counter() == 0, 'invalid count');

    start_cheat_caller_address(safe_dispatcher.contract_address, OSCAR());
    
    match safe_dispatcher.reset_counter() {
        Result::Ok(_) => panic!("cannot reset"),
        Result::Err(e) => {
            let expected_first_chunk = 'Ownable: caller is not the own';
            assert(*e[0] == expected_first_chunk, 'Wrong panic message start');
        }
    };
    stop_cheat_caller_address(safe_dispatcher.contract_address);
}

#[test]
fn test_successful_reset_counter() {
    let (counter, _, _) = __deploy__();

    counter.increase_counter();
    counter.increase_counter();
    counter.increase_counter();
    counter.increase_counter(); 
    counter.increase_counter();

    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid count setup');

    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    let count_2 = counter.get_counter();
    assert(count_2 == 0, 'counter not reset to 0');
}