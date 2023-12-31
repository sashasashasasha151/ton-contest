import "@stdlib/deploy";
/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
*/

struct Proxy {
    address: Address;
    msg: Cell;
}

message(0x44) Refund {
    queryId: Int as uint64;
    sender: Address;
}

contract Task2 with Deployable {
    admin: Address;
    init(admin: Address){
        self.admin = admin;
    }

    receive(msg: Slice){
        send(SendParameters{to: self.admin, value: 0, mode: SendRemainingValue + SendIgnoreErrors, bounce: false, body: Proxy{address: sender(), msg: msg.asCell()}.toCell()});
    }
    
    receive(msg: Refund){
        require(sender() == self.admin, "Only admin can refund");
        send(SendParameters{to: msg.sender, value: 0, mode: SendRemainingValue + SendIgnoreErrors, bounce: false});
    }

}
