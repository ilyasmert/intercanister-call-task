import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import CanisterDeclarations "../shared/CanisterDeclarations";

actor class Bucket(mainCanisterId : Text) = this {
    var mapBucket = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);

    stable var mapBucketArray : [(Text, Text)] = [];

    system func preupgrade() : () {
        mapBucketArray := Iter.toArray(mapBucket.entries());
    };

    system func postupgrade() : () {
        mapBucket := HashMap.fromIter<Text, Text>(Iter.fromArray(mapBucketArray), 0, Text.equal, Text.hash);
        mapBucketArray := [];
    };

    public shared ({ caller }) func add(key : Text, val : Text) : async Result.Result<(), Text> {
        if (mapBucket.size() >= 2) {
            return #err("canister capacity is full..");
        };

        mapBucket.put(key, val);

        if (mapBucket.size() == 2) {
            let mainCanister = CanisterDeclarations.getMainCanister(mainCanisterId);
            ignore await mainCanister.createNewBucketCanister();
        };

        return #ok();
    };

    public shared query ({ caller }) func read(key : Text) : async Result.Result<Text, Text> {
        if (not Principal.equal(caller, Principal.fromText(mainCanisterId))){
            return #err("caller is not main");
        };

        switch(mapBucket.get(key)) {
            case (null) {
                return #err("not found...");
            };
            case (?val) {
                return #ok(val);
            };
        };
    };
};