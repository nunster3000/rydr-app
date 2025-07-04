//
//  UserSessionManager.swift
//  RydrPlayground
//
//  Created by Khris Nunnally on 6/14/25.
//
import Foundation
import SwiftUI

class UserSessionManager: ObservableObject {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    
    func login(name: String, email: String) {
        userName = name
        userEmail = email
        isLoggedIn = true
    }
    
    func logout() {
        userName = ""
        userEmail = ""
        isLoggedIn = false
    }
}

