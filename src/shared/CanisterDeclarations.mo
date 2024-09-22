import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

module {
    public type ContentType = {
        contentId : Text;
        content : Text;
        key : Text;
        owner : Text;
        date : Text;
    };

    public type MainCanisterInterface = actor {
        createNewBucketCanister : () -> async Result.Result<Text, Text>;
    };

    public func getMainCanister(mainCanisterId : Text) : MainCanisterInterface {
        let canister : MainCanisterInterface = actor(mainCanisterId);
        return canister;
    };

    public type BucketCanisterInterface = actor {
        add : (key : Text, val : Text, contentId : Nat, callerPrincipalId : Principal) -> async Result.Result<Text, Text>;
        read : query (key : Text, contentId : Nat, receiverPrincipalId : Principal) -> async Result.Result<ContentType, Text>;
    };

    public func getBucketCanister(canisterId : Text) : BucketCanisterInterface {
        let canister : BucketCanisterInterface = actor(canisterId);
        return canister;
    };
};