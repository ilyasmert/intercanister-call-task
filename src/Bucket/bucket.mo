import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Time "mo:base/Time";
import Int "mo:base/Int";
import CanisterDeclarations "../shared/CanisterDeclarations";

actor class Bucket(mainCanisterId : Text) = this {

    var contentIdToContentMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    var contentIdToOwnerPrincipalMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    var contentIdToKeyMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    var contentIdToDateMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);

    stable var contentIdToContentMapArray : [(Text, Text)] = [];
    stable var contentIdToOwnerPrincipalMapArray : [(Text, Text)] = [];
    stable var contentIdToKeyMapArray : [(Text, Text)] = [];
    stable var contentIdToDateMapArray : [(Text, Text)] = [];

    system func preupgrade() : () {
        contentIdToContentMapArray := Iter.toArray(contentIdToContentMap.entries());
        contentIdToOwnerPrincipalMapArray := Iter.toArray(contentIdToOwnerPrincipalMap.entries());
        contentIdToKeyMapArray := Iter.toArray(contentIdToKeyMap.entries());
        contentIdToDateMapArray := Iter.toArray(contentIdToDateMap.entries());
    };

    system func postupgrade() : () {
        contentIdToContentMap := HashMap.fromIter<Text, Text>(Iter.fromArray(contentIdToContentMapArray), 0, Text.equal, Text.hash);
        contentIdToContentMapArray := [];
        contentIdToOwnerPrincipalMap := HashMap.fromIter<Text, Text>(Iter.fromArray(contentIdToOwnerPrincipalMapArray), 0, Text.equal, Text.hash);
        contentIdToOwnerPrincipalMapArray := [];
        contentIdToKeyMap := HashMap.fromIter<Text, Text>(Iter.fromArray(contentIdToKeyMapArray), 0, Text.equal, Text.hash);
        contentIdToKeyMapArray := [];
        contentIdToDateMap := HashMap.fromIter<Text, Text>(Iter.fromArray(contentIdToDateMapArray), 0, Text.equal, Text.hash);
        contentIdToDateMapArray := [];
    };

    private func safeGet<K, V>(hashMap : HashMap.HashMap<K, V>, key : K, defaultValue : V) : V {
        switch (hashMap.get(key)) {
            case null defaultValue;
            case (?value) value;
        };
    };

    private func formatTimestamp(seconds : Int) : Text {
        let minute = 60;
        let hour = 60 * minute;
        let day = 24 * hour;
        let year = 365 * day;

        let yearsPassed = seconds / year + 1970;
        let daysRemaining = seconds % year;
        let monthsPassed = daysRemaining / day / 30 + 1;
        let daysPassed = (daysRemaining / day % 30) + 1;
        let hoursPassed = (seconds % day) / hour;
        let minutesPassed = (seconds % hour) / minute;
        let secondsPassed = seconds % minute;

        return (
            Int.toText(yearsPassed) # "-" # Int.toText(monthsPassed) # "-" # Int.toText(daysPassed) # " " #
            Int.toText(hoursPassed) # ":" # Int.toText(minutesPassed) # ":" # Int.toText(secondsPassed)
        );
    };

    private func buildContent(contentId : Nat) : CanisterDeclarations.ContentType {
        {
            contentId = Nat.toText(contentId);
            content = safeGet(contentIdToContentMap, Nat.toText(contentId), "not found");
            key = safeGet(contentIdToKeyMap, Nat.toText(contentId), "not found");
            owner = safeGet(contentIdToOwnerPrincipalMap, Nat.toText(contentId), "not found");
            date = safeGet(contentIdToDateMap, Nat.toText(contentId), "not found");
        };
    };

    public shared func add(key : Text, val : Text, contentId : Nat, callerPrincipalId : Principal) : async Result.Result<Text, Text> {

        if (contentIdToKeyMap.size() >= 2) {
            return #err("bucket canister is full..");
        };

        let now = Time.now();
        let currentSeconds = now / 1_000_000_000;
        let currentTime = formatTimestamp(currentSeconds);

        contentIdToKeyMap.put(Nat.toText(contentId), key);
        contentIdToContentMap.put(Nat.toText(contentId), val);
        contentIdToOwnerPrincipalMap.put(Nat.toText(contentId), Principal.toText(callerPrincipalId));
        contentIdToDateMap.put(Nat.toText(contentId), currentTime);

        if (contentIdToKeyMap.size() == 2) {
            let mainCanister = CanisterDeclarations.getMainCanister(mainCanisterId);
            ignore await mainCanister.createNewBucketCanister();
        };

        return #ok(val);
    };

    public shared query ({ caller }) func read(key : Text, contentId : Nat, receiverPrincipalId : Principal) : async Result.Result<CanisterDeclarations.ContentType, Text> {
        if (not Principal.equal(caller, Principal.fromText(mainCanisterId))){
            return #err("caller is not main");
        };

        let principalAndKey = Principal.toText(receiverPrincipalId) # "_" # key;

        let returnedContent = buildContent(contentId);

        return #ok(returnedContent);
    };
};