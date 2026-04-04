package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.exception.ValidationException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.deposit.DepositRequest;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;

public interface ManagementService {

    BaseResponse createUser(CreateRequest createRequest) throws DatabaseException, ValidationException;
    FetchUserResponse getUser(String userKey) throws DatabaseException;
    User findUserInDatabase(String userKey) throws DatabaseException;
    BaseResponse depositBalance(String uid, DepositRequest depositRequest) throws DatabaseException, ValidationException;
}
