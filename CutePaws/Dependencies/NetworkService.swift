//
//  NetworkService.swift
//  CutePaws
//
//  Created by Vijay Raj Dixit on 29/01/26.
//


import Foundation

protocol NetworkService {
    func requestAsync<T: Decodable>(_ request: URLRequest) async throws -> T
}
