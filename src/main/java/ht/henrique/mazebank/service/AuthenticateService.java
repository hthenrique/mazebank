package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;

public interface AuthenticateService {

    BaseResponse authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException;
}
