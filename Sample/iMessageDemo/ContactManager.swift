import Foundation
import Contacts
import Combine

@MainActor
class ContactManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var hasAccess: Bool = false
    
    private let store = CNContactStore()
    private var contactCache: [String: String] = [:]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func toggleContactLookup() {
        if hasAccess {
            isEnabled.toggle()
        } else {
            requestContactAccess()
        }
    }
    
    private func checkAuthorizationStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        hasAccess = (status == .authorized)
    }
    
    private func requestContactAccess() {
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasAccess = granted
                if granted {
                    self?.isEnabled = true
                }
            }
        }
    }
    
    func lookupContactName(for identifier: String) -> String? {
        guard isEnabled && hasAccess else { return nil }
        
        // Check cache first
        if let cachedName = contactCache[identifier] {
            return cachedName
        }
        
        // Perform lookup
        let displayName = performContactLookup(identifier) ?? identifier
        
        // Cache the result (even if nil, to avoid repeated lookups)
        contactCache[identifier] = displayName
        
        return displayName
    }
    
    private func performContactLookup(_ identifier: String) -> String? {
        return findContactByPhoneNumber(identifier) ?? findContactByEmail(identifier)
    }
    
    private func findContactByPhoneNumber(_ phoneNumber: String) -> String? {
        do {
            let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: phoneNumber))
            return try findContactWithPredicate(predicate)
        } catch {
            return nil
        }
    }
    
    private func findContactByEmail(_ email: String) -> String? {
        do {
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
            return try findContactWithPredicate(predicate)
        } catch {
            return nil
        }
    }
    
    private func findContactWithPredicate(_ predicate: NSPredicate) throws -> String? {
        // Get all keys that CNContactFormatter might need
        let keysToFetch = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        let additionalKeys = [
            CNContactNicknameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
        ] as [CNKeyDescriptor]
        
        let allKeys = [keysToFetch] + additionalKeys
        
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: allKeys)
        
        guard let contact = contacts.first else { return nil }
        
        // Use nickname if available
        if !contact.nickname.isEmpty {
            return contact.nickname
        }
        
        // Use CNContactFormatter for proper display name formatting
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        
        if let displayName = formatter.string(from: contact), !displayName.isEmpty {
            return displayName
        }
        
        return nil
    }
    
    func clearCache() {
        contactCache.removeAll()
    }
}
