import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import org.apache.log4j.Logger;

public class MemoryExample {

    private static final Logger LOGGER = Logger.getLogger(MemoryExample.class);

    public static void main(String... args) {
        try {
            Class.forName("org.hsqldb.jdbcDriver");
        } catch (Exception e) {
            System.out.println("ERROR: failed to load HSQLDB JDBC driver.");
            e.printStackTrace();
            return;
        }

        Connection c = null;
        try {
            c = DriverManager.getConnection("jdbc:hsqldb:mem:bdays", "sa", "");
            if (c != null) {
                c.close();
                LOGGER.info("Memory Test OK.");
            }
        } catch (SQLException e) {
            LOGGER.error("ERROR: failed to connect to server.", e);
            return;
        }

    }
}
