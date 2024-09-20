import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import CanisterDeclarations "../shared/CanisterDeclarations";

actor class Bucket(mainCanisterId : Text) = this {
    //var mapBucket = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);

    var size : Nat = 0;
    stable var mapBucket = Map.new<Text, Map.Map<Text, Text>>();

    //stable var mapBucketArray : [(Text, Text)] = [];

    system func preupgrade() : () {
        //mapBucketArray := Iter.toArray(mapBucket.entries());
    };

    system func postupgrade() : () {
        /* mapBucket := HashMap.fromIter<Text, Text>(Iter.fromArray(mapBucketArray), 0, Text.equal, Text.hash);
        mapBucketArray := []; */
    };

    public shared func add(key : Text, val : Text, caller : Principal) : async Result.Result<Text, Text> {

        let bucketCaller = Principal.toText(caller);
        let innerMap = Map.get(mapBucket, thash, bucketCaller);

        switch(innerMap) {
            case(?innerMap) {
                Map.set(innerMap, thash, key, val);
                size += 1;
                //return #err(Nat.toText(size));
            };
            case(null) {
                let newInnerMap = Map.new<Text, Text>();
                Map.set(newInnerMap, thash, key, val);
                size := 1;
                Map.set(mapBucket, thash, bucketCaller, newInnerMap);
            };
        };

        if (size == 2) {
            let mainCanister = CanisterDeclarations.getMainCanister(mainCanisterId);
            ignore await mainCanister.createNewBucketCanister();
        };

        return #ok(val);
    };

    public shared query ({ caller }) func read(key : Text, receiver : Principal) : async Result.Result<(Text, Text), Text> {
        if (not Principal.equal(caller, Principal.fromText(mainCanisterId))){
            return #err("caller is not main");
        };

        let bucketReceiver = Principal.toText(receiver);
        let innerMap = Map.get(mapBucket, thash, bucketReceiver);

        switch(innerMap) {
            case (null) {
                return #err("user have not added anything...");
            };
            case (?innerMap) {
                switch(Map.get(innerMap, thash, key)) {
                    case (null) {
                        return #err("not found..");
                    };
                    case (?val) {
                        return #ok(bucketReceiver, val);
                    };
                };
            };
        };
    };
};