import Result "mo:base/Result";
import Text "mo:base/Text";

module {
    public type MainCanisterInterface = actor {
        createNewBucketCanister : () -> async Result.Result<Text, Text>;
    };

    public func getMainCanister(mainCanisterId : Text) : MainCanisterInterface {
        let canister : MainCanisterInterface = actor(mainCanisterId);
        return canister;
    };

    public type BucketCanisterInterface = actor {
        add : (key : Text, val : Text) -> async Result.Result<Text, Text>;
        read : query (key : Text) -> async Result.Result<Text, Text>;
    };

    public func getBucketCanister(canisterId : Text) : BucketCanisterInterface {
        let canister : BucketCanisterInterface = actor(canisterId);
        return canister;
    };
};