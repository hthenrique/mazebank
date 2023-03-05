package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import org.springframework.http.ResponseEntity;

public interface ManagementService {

    ResponseEntity<BaseResponse> createUser(CreateRequest createRequest) throws DatabaseException;
}
