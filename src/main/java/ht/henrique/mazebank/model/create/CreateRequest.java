package ht.henrique.mazebank.model.create;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class CreateRequest {

    private String username;
    private String useremail;
    private String userpass;

}
