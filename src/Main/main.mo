import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Bucket "../Bucket/bucket";
import CanisterDeclarations "../shared/CanisterDeclarations";

actor Main {

  var admins = Buffer.Buffer<Principal>(0);

  public func addMe() : async () {
    admins.add(Principal.fromText("arorh-yq4cx-ccxg6-l6lqt-5fygp-np567-ak5ti-43yol-priam-jgn4z-iqe"));
  };

  var bucketCanisterIds = HashMap.HashMap<Text, Bool>(0, Text.equal, Text.hash);
  var principalAndKeyToContentIdMap = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  var contentIdToBucketCanisterIdMap = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);


  stable var adminsArray : [Principal] = [];
  stable var bucketCanisterIdsArray : [(Text, Bool)] = [];
  stable var principalAndKeyToContentIdMapArray : [(Text, Nat)] = [];
  stable var contentIdToBucketCanisterIdMapArray : [(Text, Text)] = [];

  stable var contentIdCounter : Nat = 0;
  stable var activeBucketCanisterId : Text = "";

  system func preupgrade() : () {
    adminsArray := Buffer.toArray<Principal>(admins);
    bucketCanisterIdsArray := Iter.toArray(bucketCanisterIds.entries());
    principalAndKeyToContentIdMapArray := Iter.toArray(principalAndKeyToContentIdMap.entries());
    contentIdToBucketCanisterIdMapArray := Iter.toArray(contentIdToBucketCanisterIdMap.entries());
  };

  system func postupgrade() : () {
    admins := Buffer.fromArray(adminsArray);
    adminsArray := [];
    bucketCanisterIds := HashMap.fromIter<Text, Bool>(Iter.fromArray(bucketCanisterIdsArray), 0, Text.equal, Text.hash);
    bucketCanisterIdsArray := [];
    principalAndKeyToContentIdMap := HashMap.fromIter<Text, Nat>(Iter.fromArray(principalAndKeyToContentIdMapArray), 0, Text.equal, Text.hash);
    principalAndKeyToContentIdMapArray := [];
    contentIdToBucketCanisterIdMap := HashMap.fromIter<Text, Text>(Iter.fromArray(contentIdToBucketCanisterIdMapArray), 0, Text.equal, Text.hash);
    contentIdToBucketCanisterIdMapArray := [];
  };

  private func isAdmin(p : Principal) : Bool {
    return Buffer.contains<Principal>(admins, p, Principal.equal);
  };

  private func isAnonymous(p : Text) : Bool {
    if (p == "2vxsx-fae") {
      return true;
    } else false;
  };

  private func isBucketCanister(caller : Principal) : Bool {
    switch(bucketCanisterIds.get(Principal.toText(caller))) {
      case(null) {
        return false;
      };
      case(?val) {
        return true;
      };
    };
  };

  public shared ({ caller }) func addAdmin(p : Text) : async Result.Result<(), Text> {
    if (not isAdmin(caller)) {
      return #err("unauthorized..");
    };

    if (isAnonymous(Principal.toText(caller))) {
      return #err("anonymous user can not add admin..");
    };

    admins.add(Principal.fromText(p));
    return #ok();
  };

  public shared query ({ caller }) func getAdmins() : async Result.Result<[Principal], Text> {
    if (not isAdmin(caller)) {
      return #err(Principal.toText(caller));
    };

    return #ok(Buffer.toArray(admins));
  };

  public shared ({ caller }) func removeAdmin(p : Text) : async Result.Result<(), Text> {
    if (not isAdmin(caller)) {
      return #err("unauthorized..");
    };

    if (isAnonymous(Principal.toText(caller))) {
      return #err("anonymous user can not add admin..");
    };

    admins.filterEntries(func(_, x : Principal) {
      return x != Principal.fromText(p);
    });

    return #ok();
  };

  public shared ({ caller }) func createNewBucketCanister() : async Result.Result<Text, Text> {
    if (not isAdmin(caller) and not Principal.equal(caller, Principal.fromActor(Main)) and not isBucketCanister(caller)) {
      return #err("unauthorized..");
    };

    if (isAnonymous(Principal.toText(caller))) {
      return #err("anonymous user can not add admin..");
    };

    if (activeBucketCanisterId != "") {
      bucketCanisterIds.put(activeBucketCanisterId, false);
      activeBucketCanisterId := "";
    };

    try {
      Cycles.add<system>(500_000_000_000);
      let bucketCanister = await Bucket.Bucket(Principal.toText(Principal.fromActor(Main)));
      let canisterId = Principal.toText(Principal.fromActor(bucketCanister));
      activeBucketCanisterId := canisterId;
      bucketCanisterIds.put(activeBucketCanisterId, true);
      return #ok(canisterId);
    } catch(_) {
      return #err("an error occurred while creating the bucket canister..");
    };
  };

  public shared ({ caller }) func initializeBucketCanister() : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("unauthorized..");
    };

    if (isAnonymous(Principal.toText(caller))) {
      return #err("anonymous user can not initialize..");
    };

    if(activeBucketCanisterId == "") {
      return await createNewBucketCanister();
    } else {
      return #err("already initialized..");
    };
  };

  public shared ({ caller }) func store(key : Text, val : Text) : async Result.Result<Text, Text> {
    if (isAnonymous(Principal.toText(caller))) {
      return #err("anonymous user can not store..");
    };

    let principalAndKey = Principal.toText(caller) # "_" # key;

    if (principalAndKeyToContentIdMap.get(principalAndKey) == null) {
      contentIdCounter += 1;
    };

    principalAndKeyToContentIdMap.put(principalAndKey, contentIdCounter);
    contentIdToBucketCanisterIdMap.put(Nat.toText(contentIdCounter), activeBucketCanisterId);

    let bucketCanister = CanisterDeclarations.getBucketCanister(activeBucketCanisterId);
    await bucketCanister.add(key, val, contentIdCounter, caller);
  };

  public shared composite query ({ caller }) func getData(key : Text) : async Result.Result<CanisterDeclarations.ContentType, Text> {

    let principalAndKey = Principal.toText(caller) # "_" # key;

    switch(principalAndKeyToContentIdMap.get(principalAndKey)) {
      case (null) {
        return #err("not found..");
      };
      case (?val) {
        switch(contentIdToBucketCanisterIdMap.get(Nat.toText(val))) {
          case(null) {
            return #err("content lost..");
          };
          case(?searchedCanisterId) {
            let bucketCanister = CanisterDeclarations.getBucketCanister(searchedCanisterId);
            await bucketCanister.read(key, val, caller);
          };
        };
      };
    };
  };

  public query func getBucketCanisterIds() : async Result.Result<[(Text, Bool)], Text> {
    if (bucketCanisterIds.size() == 0) {
      return #err("there's no bucket canister..");
    };

    return #ok(Iter.toArray(bucketCanisterIds.entries()));
  };
};
