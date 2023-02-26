package ht.henrique.mazebank.controller;

import ht.henrique.mazebank.model.create.CreateResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/management")
public class ManagementController {

    @PostMapping("/create")
    public ResponseEntity<CreateResponse> createUser(){
        return ResponseEntity.ok(new CreateResponse("Crated with success"));
    }


}
