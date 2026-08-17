package ht.henrique.mazebank.model.create;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Locale;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class CreateRequest {

    private String username;
    private String useremail;
    private String userpass;

    public void setUseremail(String useremail) {
        this.useremail = useremail != null ? useremail.trim().toLowerCase(Locale.ROOT) : null;
    }

}
