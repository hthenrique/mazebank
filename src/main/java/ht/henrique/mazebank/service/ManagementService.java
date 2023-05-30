package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.deposit.DepositRequest;

public interface ManagementService {

    BaseResponse createUser(CreateRequest createRequest) throws DatabaseException;
    BaseResponse getUser(String userKey) throws DatabaseException;
    BaseResponse depositValue(Long userId, DepositRequest depositRequest) throws DatabaseException;
}
